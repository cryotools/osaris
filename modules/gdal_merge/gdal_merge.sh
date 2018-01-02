#!/bin/bash

######################################################################
#
# OSARIS module to merge grids using GDAL.
#
# Primarily intended for overlapping grids, e.g. to merge interferograms
# from neighboring S1 slices.
#
# David Loibl, 2018
#
#####################################################################

start=`date +%s`

if [ ! -f "$OSARIS_PATH/config/gdal_merge.config" ]; then
    echo
    echo "Cannot open $OSARIS_PATH/config/gdal_merge.config. Please provide a valid config file in the OSARIS config folder."
    echo
    exit 2
else
    
    echo; echo "Merging files with GDAL"
        
    source $OSARIS_PATH/config/gdal_merge.config

    gdal_translate -a_srs EPSG:4326 -co interleave=pixel -a_ullr -180.0 90.0 180.0 -90.0 0.jpg ONE.tif
    gdal_translate -a_srs EPSG:4326 -co interleave=pixel -a_ullr -90.0 90.0 90.0 -90.0 0.jpg TWO.tif

    gdalbuildvrt -input_file_list my_list.txt doq_index.vrt

    gdal_translate ONETWO.vrt ONETWO.tif


    echo; echo
    echo "Cleaning up"
    rm -r temp
    rm merged_dem.grd
    echo; echo

    end=`date +%s`

    runtime=$((end-start))

    printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n' $(($runtime/86400)) $(($runtime%86400/3600)) $(($runtime%3600/60)) $(($runtime%60))
    echo


fi


