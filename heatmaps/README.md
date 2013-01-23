# Simple heatmaps

## Example

    perl heatmaps/plot_heatmap.pl --colourfile heatmaps/colors.png --latitude 53.45 --longitude -2.30 --zoom 11 --output /var/www/output.png gpsdata.csv

## Options

    --latitude LA     latitude of the centre point (52.5)
    --longitude LO    longitude of the centre point (-1.5)
    --zoom Z          zoom level according to google (7)
    --colourfile PNG  heatmap palette (colors.png)
    --output PNG      output filename (STDOUT if not given)
    --size WxH        pixel size of the output (600x600, max 640x640)
    --clatitude N     which field of the CSV contains the latitude (1)
    --clongitude N    which field of the CSV contains the longitude (2)
    --fieldnames      try and guess the fields with lat/long (off)
    --no-gmap         don't fetch and merge the google static map
    --auto            calculate the centre lat/long and zoom from the data (off)
    --bound PLACE     restrict the output to a certain bounding box
    --fade            darken the static map before compositing
    --static NAME     select a different static map provider
    --listp           list the providers we know about

## Input
Simple CSV with latitude and longitude in distinct fields.

## Providers

[Example montage of outputs](http://backup.frottage.org/rjp/tmp/20130123/montage.jpg)

[More about the ojw/* providers](http://ojw.dev.openstreetmap.org/StaticMapDev/)
