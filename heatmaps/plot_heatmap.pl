#! /usr/bin/perl

use Image::Magick;
use Getopt::Long;
use LWP::Simple;

my $size = '600x600';
my $output = undef;
my $colourfile = "colors.png";

# reasonable defaults for most of Britain
my $centre_lat = '52.5';
my $centre_long = '-1.5';
my $zoom = 7;

my $result = GetOptions(
    "latitude=f" => \$centre_lat,
    "longitude=f" => \$centre_long,
    "zoom=i" => \$zoom,
    "size=s" => \$size,
    "output=s" => \$output,
    "colourfile=s" => \$colourfile,
);

if ($size !~ /^(\d+)x(\d+)$/) {
    die "Error: size must be {number}x{number}, you wanted $size";
}

my ($width, $height) = $size =~ /^(\d+)x(\d+)$/;
if ($width > 640 or $height > 640) {
    die "Error: size must be less than 640x640, you wanted $size";
}

if (! -r $colourfile) {
    die "Error: $colourfile is not readable";
}

my $static_map = "http://maps.google.com/maps/api/staticmap?size=${size}&sensor=false&center=${centre_lat},${centre_long}&zoom=${zoom}";

my $image = Image::Magick->new();
$image->Set(size=>$size);
$image->Set(format=>'png');
$image->ReadImage('xc:black', $colourfile);
my $radius = 1;

# magic FH, STDIN or files on commandline
while (<>) {
    my ($lat, $long) = split /,/;
    my ($px, $py, $wpx, $wpy) = ll_to_px($lat, $long, $centre_lat, $centre_long, $zoom, $width, $height);
    my $points = sprintf("%d,%d %d,%d", $px, $py, $px+$radius, $py+$radius);
    if ($px >= 0 and $px <= $width and $py >= 0 and $py <= $height) {
        $image->[0]->Draw(primitive=>'circle',stroke=>'none',fill=>'#CCCCCCF4',points=>$points);
    }
}

$image->[0]->ContrastStretch(channel => 'All', levels => '5%');
$image->[0]->Blur(radius => 2, sigma => 2);
$image->[0]->Set(type => 'TrueColorMatte');
my $p = $image->Fx(expression=>"v.p{0,u*v.h}");

$| = 1;
binmode STDOUT;

my $gmap = get($static_map);
if (defined $gmap) { # we got our static map
    use IO::String;
    my $data = IO::String->new($gmap);
    my $png = Image::Magick->new(magick=>'png');
    my $x = $png->BlobToImage($gmap);
    die "$x" if "$x";
    $png->Composite(image => $p, compose => 'Multiply', gravity => 'center');
    if (not defined $output) {
        $png->Write('png:-');
        print STDERR "combined heatmap/gmap written to STDOUT\n";
    } else {
        $png->Write($output);
        print STDERR "combined heatmap/gmap written to $output\n";
    }
} else {
    print STDERR "# couldn't fetch static gmap, try these commands:\n";
    my $to = 'your_stdout.png';
    if (not defined $output) {
        $p->Write('png:-');
    } else {
        $p->Write($output);
        $to = $output;
    }
    print STDERR "wget -O tmp.png '$static_map'\n";
    print STDERR "composite -compose Multiply -gravity center $to tmp.png heatmap.png\n";
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

while (<DATA>) {
    chomp;
#    print "$_ => ",join(',', ll_to_px(split(/,/))),"\n";
}
__DATA__
0,0,0,0,11,512,512
58.3756113333,26.7547026667,58.3756113333,26.7547026667,11,512,512
