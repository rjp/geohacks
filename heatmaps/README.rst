Simple heatmaps
===============

Example
-------

::

  perl heatmaps/plot_heatmap.pl --colourfile heatmaps/colors.png --latitude 53.45 --longitude -2.30 --zoom 11 --output /var/www/output.png gpsdata.csv

Options
-------
--latitude  latitude of the centre point (52.5)
--longitude  longitude of the centre point (-1.5)
--zoom  zoom level according to google (7)
--colourfile  heatmap palette (colors.png)
--output  output filename (STDOUT if not given)
--size  pixel size of the output (600x600, max 640x640)
--clatitude  which field of the CSV contains the latitude (1)
--clongitude  which field of the CSV contains the longitude (2)
--fieldnames  try and guess the fields with lat/long (off)
--no-gmap  don't fetch and merge the google static map
--auto_lat  calculate the centre lat/long and zoom from the data (off)

Input
-----
Simple CSV with latitude and longitude in distinct fields
