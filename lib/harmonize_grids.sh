#!/usr/bin/env bash

######################################################################
#
# Harmonize a series of grid files relative to a reference point.
#
# David Loibl, 2018
#
#####################################################################


if [ $# -lt 3 ]; then
    echo
    echo "Harmonize a series of grid files relative to a reference point."
    echo 
    echo "Usage: harmonize_grids.sh input_path reference_point output_path"  
    echo
    echo " Shift all grid files in input directory by their offset relative to a "
    echo " 'stable ground point'. Most commonly used to harmonize a time series of "
    echo " unwrapped intereferograms or LoS displacement grids."
    echo 
    echo " Arguments: "
    echo "   Input path       -> The directory containing grid files"
    echo "   Reference point  -> Coordinates of reference point in decimal degrees using the format"
    echo "                       Longitude/Latitude, e.g. 165.1/-12.5"
    echo "                       Alternatively, set to 'median' to harmonize grids to their respective medians"
    echo "   Output path      -> Output grids will be written here"
    echo 
    echo " Output:"
    echo "   Harmonized series of .grd files."; echo

else    
    HG_start=`date +%s`
    echo; echo "Harmonizing grids to reference point ..."

    # Read attributes and setup environment
    grid_input_PATH=$1
    ref_point_xy_coords=$2
    HG_output_PATH=$3
    HG_work_PATH="$work_PATH/Harmonize-Grids"
   
    mkdir -p $HG_output_PATH
    mkdir -p $HG_work_PATH
    
    if [ "$ref_point_xy_coords" == "median" ]; then
	echo "Harmonizing grids to their respective medians."
    else
	echo "Reference point is set to $ref_point_xy_coords"
	ref_point_array=(${ref_point_xy_coords//\// })
	echo "${ref_point_array[0]} ${ref_point_array[1]}" > $HG_work_PATH/ref_point.xy
    fi

                
    if [ ! -d "$grid_input_PATH" ]; then
	echo; echo "ERROR: Directory $grid_input_PATH does not exist. Skipping ..."
    else
	
	cd $grid_input_PATH

	grid_input_PATH_basename=$( basename "$PWD" )
	mkdir -p ${HG_output_PATH}/${grid_input_PATH_basename}	    

	grid_files=($( ls *.grd ))
	for grid_file in ${grid_files[@]}; do

	    if [ "$ref_point_xy_coords" == "median" ]; then
		# Obtain median value of grid
		ref_point_grid_val=$( gmt grdinfo -L1 $grid_file | grep median | awk '{print $3}' )
	    else
		# Get xy coordinates of 'stable ground point' from file and check the value the raster set has at this location.
		gmt grdtrack $HG_work_PATH/ref_point.xy -G${grid_input_PATH}/${grid_file} >> $HG_work_PATH/${grid_input_PATH_basename}_ref_point_vals.xyz
		ref_point_grid_trk=$( gmt grdtrack ${HG_work_PATH}/ref_point.xy -G${grid_input_PATH}/${grid_file} )

		if [ ! -z ${ref_point_grid_trk+x} ]; then
		    ref_point_grid_val=$( echo "$ref_point_grid_trk" | awk '{ print $3 }')		    
		    # if [ $debug -gt 1 ]; then echo "Stable ground diff ${grid_input_PATH}/${grid_file}: $ref_point_grid_val"; fi
		else
		    echo "GMT grdtrack for stable ground yielded no result for ${grid_input_PATH}/${grid_file}. Skipping"
		fi
	    fi
	    
	    if [ ! -z ${ref_point_grid_val+x} ]; then
		# Shift input grid so that the 'stable ground value' is zero
		gmt grdmath ${grid_input_PATH}/${grid_file} $ref_point_grid_val SUB = $HG_output_PATH/${grid_file::-4}-harmonized.grd -V
	    else 
		echo "Unwrap difference calculation for stable ground point failed in ${folder}. Skipping ..."
	    fi		    
	done	    

    fi    
    

    HG_end=`date +%s`

    HG_runtime=$((HG_end-HG_start))

    printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n' $(($HG_runtime/86400)) $(($HG_runtime%86400/3600)) $(($HG_runtime%3600/60)) $(($HG_runtime%60))
    echo


fi
