use Image::Magick;

    my $image = Image::Magick->new();
    $image->Set(size=>'600x600');
    $image->Set(format=>'png');
    $image->ReadImage('xc:black', '/home/rjp/colors.png');
    my $radius = 1;

    my $max = -9999999999;
    open F, $ARGV[0];
    while (<F>) {
        my ($date, $time, $lat, $long, $media) = split /,/;
        my ($px, $py, $wpx, $wpy) = ll_to_px($lat, $long, 52.5, -1.5, 7, 600, 600);
        my $points = sprintf("%d,%d %d,%d", $px, $py, $px+$radius, $py+$radius);
        $image->[0]->Draw(primitive=>'circle',stroke=>'none',fill=>'#CCCCCCF4',points=>$points);


            my $colour = "#00000008";
            $image->Draw(primitive=>'circle',fill=>$colour,stroke=>$colour,points=>"$px,$py ".($px+1).",".($py+1));
    }
    close F;

    $image->[0]->ContrastStretch(channel => 'All', levels => '5%');
    $image->[0]->Blur(radius => 2, sigma => 2);
    $image->[0]->Set(type => 'TrueColorMatte');
    my $p = $image->Fx(expression=>"v.p{0,u*v.h}");

    $| = 1;
    binmode STDOUT;
    $p->Write('png:-');

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
