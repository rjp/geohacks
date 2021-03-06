#! /usr/bin/perl

use Image::Magick;
use Getopt::Long;
use LWP::Simple;
use Scalar::Util qw(looks_like_number);

my $places = {
    "gnw" => [51.45,-0.05, 51.5,0.05],
    "central" => [51.425,-0.25, 51.55,0.075],
    "sale" => [53.41,-2.40, 53.46,-2.30],
    "budapest" => [47.46,19.00, 47.55,19.13],
};

my $providers = {
    'gmaps' => {
        name => 'Google Static Maps',
        url => \&static_gmaps,
        max => { w => 640, h => 640 },
    },
    'mapquest' => {
        name => 'Mapquest Open Static',
        url => \&static_mapquest,
        max => { w => 3840, h => 3840 },
    },
    'ojw/bland' => {
        name => 'OSM Statics by ojw',
        url => ojw_maker('cloudmade_998'),
        max => { w => 3200, h => 2000 },
    },
    'ojw/night' => {
        name => 'OSM Statics by ojw',
        url => ojw_maker('cloudmade_999'),
        max => { w => 3200, h => 2000 },
    },
    'ojw/strong' => {
        name => 'OSM Statics by ojw',
        url => ojw_maker('cloudmade_5'),
        max => { w => 3200, h => 2000 },
    },
    'ojw/grey' => {
        name => 'OSM Statics by ojw',
        url => ojw_maker('cloudmade_998', '&filter=grey'),
        max => { w => 3200, h => 2000 },
    },
    'ojw/osm' => {
        name => 'OSM Statics by ojw',
        url => ojw_maker('mapnik'),
        max => { w => 3200, h => 2000 },
    },
};

## NO USER-SERVICEABLE PARTS BELOW ##

my $size = '600x600';
my $output = undef;
my $colourfile = "colors.png";
my $col_lat = 1;
my $col_long = 2;
my $fieldnames = undef;
my $draw_gmap = 1;
my $auto_lat = undef;
my $bound = undef;
my $force_zoom = undef;
my $osm_statics = undef;
my $fade = undef;
my $static = 'gmaps'; # default provider in $providers
my $listp = undef;

# reasonable defaults for most of Britain
my $centre_lat = '52.5';
my $centre_long = '-1.5';
my $default_zoom = 7;
my $zoom = undef;

my $result = GetOptions(
    "latitude=f" => \$centre_lat,
    "longitude=f" => \$centre_long,
    "zoom=i" => \$zoom,
    "size=s" => \$size,
    "output=s" => \$output,
    "colourfile=s" => \$colourfile,
    "clatitude=i" => \$col_lat,
    "clongitude=i" => \$col_long,
    "fieldnames" => \$fieldnames,
    "bound=s" => \$bound,
    "gmap!" => \$draw_gmap,
    "auto!" => \$auto_lat,
    "map!"  => \$draw_gmap,
    "osm!"  => \$osm_statics,
    "fade!" => \$fade,
    "static=s" => \$static,
    "listp" => \$listp,
);

if (defined $listp) {
    foreach my $key (sort keys %{$providers}) {
        my $provider = $providers->{$key};
        printf "%-15s %s (%s)\n", $key, $provider->{name},
            join('x', $provider->{max}->{w}, $provider->{max}->{h});
    }
    exit 0;
}

if ($size !~ /^(\d+)x(\d+)$/) {
    die "Error: size must be {number}x{number}, you wanted $size";
}

my $provider = $providers->{$static};
if (not defined $provider) {
    my $list = join(', ', keys %{$providers});
    die "Unknown provider '${static}'. Known are: ${list}";
}

my ($max_w, $max_h) = ($provider->{max}->{w}, $provider->{max}->{h});

my ($width, $height) = $size =~ /^(\d+)x(\d+)$/;
if ($width > $max_w) {
    die "Error: width for ${static} must be less than ${max_w} (limits: ${max_w} x ${max_h})";
}
if ($height > $max_h) {
    die "Error: height for ${static} must be less than ${max_h} (limits: ${max_w} x ${max_h})";
}

# TODO make this optional - probably don't want need 7680x7680 render at full Mapquest resolution
my ($p_width, $p_height) = (2*$width, 2*$height);
print "$size => ${p_width}x${p_height}\n";

if (defined $bound) {
    if ($bound =~ s/@(\d+)$//) {
        $force_zoom = $1;
        print "Forcing zoom to be $force_zoom\n";
    }
    if (not defined $places->{$bound}) {
        die "Error: bound [$bound] unknown";
    }
}
if (! -r $colourfile) {
    die "Error: $colourfile is not readable";
}

if (defined $zoom and defined $auto_lat) {
    print "--zoom and --auto forces zoom to be $zoom\n";
    $force_zoom = $zoom;
}

if (not defined $zoom) {
    $zoom = $default_zoom;
}

# try and find the lat/long fields from the first line
# only works for /^(long|lat)(itude|$)/
if (defined $fieldnames) {
    chomp (my $first_line = <>);
    my @fields = split /,/, $first_line;
    my $i = 1;
    foreach my $j (@fields) {
        if ($j =~ /^(latitude|lat)$/i) {
            $col_lat = $i;
        }
        if ($j =~ /^(longitude|long)$/i) {
            $col_long = $i;
        }
        $i++; # no each_with_index in perl, boo
    }
    print STDERR "found latitude at $col_lat, longitude at $col_long\n";
}

my $static_maker = \&static_gmaps;
if (defined $osm_statics) {
    $static_maker = \&static_osm;
}

# adjust human-powered column numbers into perl-powered array indexes
$col_lat--;
$col_long--;

my $image = Image::Magick->new();
$image->Set(size=>"${p_width}x${p_height}");
$image->Set(format=>'png');
$image->ReadImage('xc:black', $colourfile);
my $radius = 1;

my ($min_lat, $min_long) = (9999,9999);
my ($max_lat, $max_long) = (-9999,-9999);

my $bad_lines = 0;

# magic FH, STDIN or files on commandline
my @points = ();
while (<>) {
    chomp;
    next if /^\s*$/; # ignore whitespace

    # TODO use a real CSV parser here?
    my @fields = split /,/;
    my ($lat, $long) = ($fields[$col_lat], $fields[$col_long]);

    if (not defined $lat or
        not defined $long or
        not looks_like_number $lat or
        not looks_like_number $long) {
        $bad_lines++;
        next;
    }

    # store the points here because we might need the bounds before we plot any points
    push @points, [$lat, $long];

    if ($lat < $min_lat) { $min_lat = $lat; }
    if ($long < $min_long) { $min_long = $long; }
    if ($lat > $max_lat) { $max_lat = $lat; }
    if ($long > $max_long) { $max_long = $long; }
}

if ($bad_lines > 0) {
    print STDERR "Ignored $bad_lines bad lines\n";
}

if (defined $auto_lat) {
    if (defined $bound) {
        my $box = $places->{$bound};
        ($min_lat, $min_long, $max_lat, $max_long) = @{$box};
        print STDERR "Bound[$bound]: ($min_lat, $min_long) ($max_lat, $max_long)\n";
    }
    ($centre_lat,$centre_long,$zoom) = bounds_to_zoom($min_lat,$min_long,$max_lat,$max_long,$width,$height);
    if (defined $force_zoom) {
        $zoom = $force_zoom;
    }
    print STDERR "Auto-scaling: --lat $centre_lat --long $centre_long --zoom $zoom\n";
    print STDERR "($min_lat, $min_long) ($max_lat, $max_long)\n";
}

foreach my $i (@points) {
    my ($lat, $long) = @{$i};
    my ($px, $py, $wpx, $wpy) = ll_to_px($lat, $long, $centre_lat, $centre_long, $zoom, $width, $height);
    my $points = sprintf("%d,%d", 2*$px, 2*$py);
    #my $points = sprintf("%d,%d %d,%d", $px, $py, $px+$radius, $py+$radius);
    if ($px >= 0 and $px <= $width and $py >= 0 and $py <= $height) {
        # $image->[0]->Draw(primitive=>'circle',stroke=>'none',fill=>'#CCCCCCF4',points=>$points);
        # $image->[0]->Draw(primitive=>'circle',stroke=>'none',fill=>'#111111F4',points=>$points);
        $image->[0]->Draw(primitive=>'point',stroke=>'#CCCCCCF4',fill=>'#CCCCCCF4',points=>$points);
    }
}

$image->[0]->Blur(radius => 2, sigma => 2);
$image->[0]->Transparent(color => 'black');
$image->[0]->ContrastStretch(channel => 'All', levels => '25%');
$image->[0]->Set(type => 'TrueColorMatte');
my $p = $image->Fx(expression=>"v.p{0,u*v.h}");
$p->Resize(width => $width, height => $height, blur => 1.1);

# $p->Resize(width => $width, height => $height, blur => 1.1, filter => Cubic);

$| = 1;
binmode STDOUT;

my $static_map = $provider->{url}->($centre_lat, $centre_long, $zoom, $width, $height);

my $gmap = undef;
if ($draw_gmap) {
    $gmap = get($static_map);
}
if (defined $gmap) { # we got our static map
    use IO::String;
    my $data = IO::String->new($gmap);
    my $png = Image::Magick->new(magick=>'png');
    my $x = $png->BlobToImage($gmap);
    die "$x" if "$x";

    if ($fade) {
        my $gray = Image::Magick->new();
        $gray->Set(size => "${width}x${height}");
        $gray->Set(format => 'png');
        $gray->ReadImage('xc:#808080FF');
        $png->Composite(image => $gray, compose => 'Multiply', gravity => 'center');
    }
    $png->Composite(image => $p, compose => 'Over', gravity => 'center');
    if (not defined $output) {
        $png->Write('png:-');
        print STDERR "combined heatmap/gmap written to STDOUT\n";
    } else {
        $png->Write($output);
        print STDERR "combined heatmap/gmap written to $output\n";
    }
} else {
    my $to = 'your_stdout.png';
    if (not defined $output) {
        $p->Write('png:-');
    } else {
        $p->Write($output);
        $to = $output;
    }
    if ($draw_gmap) { # wanted static map, couldn't fetch it
        print STDERR "couldn't fetch static gmap, try these commands:\n";
    } else { # didn't want static map, didn't fetch it
        print STDERR "heatmap layer rendered to $to, use these commands to merge:\n";
    }
    print STDERR "wget -O tmp.png '$static_map'\n";
    print STDERR "composite -compose Multiply -gravity center $to tmp.png heatmap.png\n";
}

sub static_mapquest {
    my ($lat, $long, $zoom, $w, $h) = @_;

    return "http://open.mapquestapi.com/staticmap/v4/getmap?size=${w},${h}&zoom=${zoom}&center=${lat},${long}&imagetype=png";
}

sub static_gmaps {
    my ($lat, $long, $zoom, $w, $h) = @_;
    my $size = "${w}x${h}";

    return "http://maps.google.com/maps/api/staticmap?size=${size}&sensor=false&center=${lat},${long}&zoom=${zoom}";
}

sub ojw_maker {
    my ($style, $extra) = @_;
    return sub {
        my ($lat, $long, $zoom, $w, $h) = @_;
        return "http://ojw.dev.openstreetmap.org/StaticMap/?lat=${lat}&lon=${long}&z=${zoom}&w=${w}&h=${h}&layer=${style}&mode=Style&att=none&show=1${extra}";
    }
}

sub pi {
    return 3.1415926;
}

sub lonToWX {
    my $lon = shift;
    my $offset = 268435456;
    my $radius = $offset / pi();
    return $offset + $radius * $lon * pi() / 180;
}

sub latToWY {
    my $lat = shift;
    my $offset = 268435456;
    my $radius = $offset / pi();
    return $offset - $radius * log((1 + sin($lat * pi() / 180)) / (1 - sin($lat * pi() / 180))) / 2;
}

sub ll_to_px {
    my ($lat, $long, $clat, $clong, $zoom, $width, $height) = @_;
    my $cwpx = lonToWX($clong);
    my $cwpy = latToWY($clat);
    my $llwpx = lonToWX($long);
    my $llwpy = latToWY($lat);
    my $dx = ($llwpx - $cwpx) / (2**(21 - $zoom));
    my $dy = ($llwpy - $cwpy) / (2**(21 - $zoom));

    return $dx + ($width/2), $dy + ($height/2),$llwpx,$llwpy;
}

sub bounds_to_zoom {
    my ($latmin, $lngmin, $latmax, $lngmax,$w,$h) = @_;
    my $clat = ($latmin+$latmax)/2;
    my $clng = ($lngmin+$lngmax)/2;
    my $hw = $w/2;
    my $hh = $h/2;
    # find the pixel coordinates of our min/max points based on zoom 9
    my ($minx, $miny) = ll_to_px($latmin, $lngmin, $clat, $clng, 9, $w, $h);
    my ($maxx, $maxy) = ll_to_px($latmax, $lngmax, $clat, $clng, 9, $w, $h);

    # work out the largest offset from our centre point
    # this determines our zoom level
    my $off_x = abs($hw-$minx); if ($maxx-$hw > $off_x) { $off_x = $maxx-$hw; }
    my $off_y = abs($hh-$miny); if ($maxy-$hh > $off_y) { $off_y = $maxy-$hh; }

# print STDERR "($minx,$miny) - ($maxx,$maxy) into ($w,$h) = \n";
# print STDERR "dx=",abs($hw-$minx),",",$maxx-$hw," ";
# print STDERR "dy=",abs($hh-$miny),",",$mayy-$hh,"\n";

    # convert our offsets into zooms based on a delta from zoom=9
    my $zx = $off_x / $hw;
    my $zoom_x = int(9 - log($zx)/log(2) - 0.25);
    my $zy = $off_y / $hh;
    my $zoom_y = int(9 - log($zy)/log(2) - 0.25);

# print STDERR "ox=$off_x, oy=$off_y, zx=$zoom_x, zy=$zoom_y\n";

    # pick the smaller zoom since it's guaranteed to fit our data
    if ($zoom_x < $zoom_y) {
        return $clat, $clng, $zoom_x;
    } else {
        return $clat, $clng, $zoom_y;
    }
}

