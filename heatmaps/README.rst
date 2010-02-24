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

Input
-----
Simple CSV with two fields, latitude and longitude.
