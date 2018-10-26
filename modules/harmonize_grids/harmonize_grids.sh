#!/usr/bin/env bash

######################################################################
#
# OSARIS module to harmonize a series of grid files relative to a 
# reference point.
#
# Shift all frid files in a directory by their offset to a 
# 'stable ground point' (by default the result from the 'SGP Identification'
# module. Most commonly used to harmonize a time series of unwrapped 
# intereferograms or LoS displacement grids.
#
# Input: 
#    - path(s) to one or more directories containing grid files
#    - xy coordinates of stable ground point (default SGPI result)
#
# Output:
#    - harmonized series of .grd files.
#
#
# David Loibl, 2018
#
#####################################################################


module_name="harmonize_grids"

if [ ! -f "$OSARIS_PATH/config/${module_name}.config" ]; then
    echo
    echo "Cannot open ${module_name}.config in the OSARIS config folder. Please provide a valid config file."
    echo
else
    # Start runtime timer
    HG_start=`date +%s`

    # Include the config file
    source $OSARIS_PATH/config/${module_name}.config


    ############################
    # Module actions start here

    echo; echo "Harmonizing grids to reference point ..."

    HG_output_PATH="$output_PATH/Harmonized-grids"   
    HG_work_PATH="$work_PATH/Harmonized-grids"

    mkdir -p $HG_output_PATH
    mkdir -p $HG_work_PATH
    
    if [ ! -z "$ref_point_xy_coords" ]; then
	echo "Reference point is set to $ref_point_xy_coords"
	ref_point_array=(${ref_point_xy_coords//\// })	
	ref_point_lon=${ref_point_array[0]}
	ref_point_lat=${ref_point_array[1]}
    elif [ -f $output_PATH/SGPI/sgp-coords.xy ]; then
	# cat $output_PATH/SGPI/sgp_coords.xy > $HG_work_PATH/ref_point.xy
	ref_point_lon=($( cat $output_PATH/SGPI/sgp-coords.xy | awk '{ print $1 }' ))
	ref_point_lat=($( cat $output_PATH/SGPI/sgp-coords.xy | awk '{ print $2 }' ))
    else
	echo "ERROR: No reference point coordinates found in harmonize_grids.config or sgp_coords.xy."
	echo "Exiting module 'Harmonize Grids'."
    fi

    for grid_dir in ${grid_input_PATH[@]}; do
	if [ ! -d "$grid_dir" ]; then
	    echo; echo "ERROR: Directory $grid_dir does not exist. Skipping ..."
	else
	    grid_dir_basename=$( basename "$grid_dir" )
	    mkdir -p ${HG_output_PATH}/${grid_dir_basename}

	    $OSARIS_PATH/lib/harmonize_grids.sh "$grid_dir" "${ref_point_lon}/${ref_point_lat}" "${HG_output_PATH}/${grid_dir_basename}"

	fi    
    done

    HG_end=`date +%s`

    HG_runtime=$((HG_end-HG_start))

    printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n' $(($HG_runtime/86400)) $(($HG_runtime%86400/3600)) $(($HG_runtime%3600/60)) $(($HG_runtime%60))
    echo


fi
