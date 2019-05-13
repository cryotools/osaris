#!/usr/bin/env bash

set -u         # Disable usage of unset variables.
set -e         # Exit when scripts return a non-true value.

if [ ! $# -eq 2 ]; then
    echo
    echo "Usage: dem-from-tifs.sh <input path> <output path>"  
    echo 
    echo "  <input path>      Path to Digital Elevation Data in GeoTiff format." 
    echo "                    No other files should be located in this directory."
    echo "  <output path>     Path where the output dem.grd file will be written."
    echo "                    The directory will be created if it does not exist."
    echo
    echo
    echo "Merge all GeoTiff files in <input path> to a single DEM called dem.grd which can be used as topo file by OSARIS."
    echo
    echo "Requires GDAL and Python."
    echo "Input GeoTiff files should be in WGS84 projection."
    echo
elif [ ! -d $1 ]; then
    echo
    echo "Error: $1 is not a valid directory."
    echo
else
    input_PATH="$1"
    output_PATH="$2"

    mkdir -p $output_PATH

    cd $input_PATH
    dem_files=($( ls *.tif ))

    if [ ${#dem_files} -eq 0 ]; then
	echo "No .tif files found in $input_PATH. Exiting."
	exit
    else
	echo; echo "Merging ${#dem_files[@]} tiles ..."
	echo "${dem_files[@]}"
	gdal_merge.py ${dem_files[@]} -o merged_dem.tif
	gmt grdconvert merged_dem.tif $output_PATH/dem-raw.grd -V
	grid_mode=$( gmt grdinfo $output_PATH/dem-raw.grd | grep 'Pixel node registration' | awk '{print $6}' )
	grid_mode=${grid_mode:1}
	if [ "$grid_mode" == "Cartesian" ]; then
	    echo; echo "Converting cartesian to geographic grid"
	    grd_extent=$( gmt grdinfo -I- $output_PATH/dem-raw.grd | awk 'NR==1' )
	    # grd_centermedian=
	    gmt grdproject $output_PATH/dem-raw.grd $grd_extent -Jm1:1 -I -G$output_PATH/dem.grd -V
	fi
	
	rm merged_dem.tif
    fi
    
fi
