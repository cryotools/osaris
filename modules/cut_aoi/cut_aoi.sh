# Workflow

# Config file must provide:
# - Input .PRM file
# - name_stems of files to process (?)
# - kml file containing the area of interest

# Extract lat/lon info from kml
gmt kml2gmt google.kml -V > lat_lon_file.llt

# Find radar coordinates for lat/lon position
# http://gmt.soest.hawaii.edu/boards/6/topics/6066
SAT_llt2rat master.PRM 0 < lat_lon_file.llt > outputfile.ratll

# extract azimuth 1 and 2 from outputfile.ratll
assemble_tops azimuth_1 azimuth_2 namestem_1 namestem_2 [...] output_stem

# Cut resulting file to AOI
# http://gmt.soest.hawaii.edu/boards/1/topics/4264
gmt gmtinfo -I1m clip.gmt

gmt grdcut output_stem.tiff -Goutput_stem_cut.grd -R../../../..

gmt grdmask clip.gmt -Retopo1_cut.grd -NNaN/1/1 -Gmask.nc

gmt grdmath grid.nc mask.nc MUL = grid_masked.nc
