#!/usr/bin/env bash

######################################################################
#
# Helper tool to change grid longitude notation from 0/360 (OSARIS 
# and GMTSAR default) to -180/180.
#
# David Loibl, 2018
#
#####################################################################


if [ $# -lt 1 ]; then
    echo
    echo "Helper tool to change grid longitude notation from 0/360 (OSARIS "
    echo "and GMTSAR default) to -180/180."
    echo 
    echo "Usage: shift_longitude_coords.sh input_path [output_path]"  
    echo
    echo " Recalculate longitude notation of all grid files in input directory "
    echo " to -180/180. If an output directory is specified, results will be "
    echo " saved there, otherwise the input files will be overwritten."
    echo 
    echo " Arguments: "
    echo "   Input path         -> The directory containing grid files"
    echo "   Output path (opt.) -> Output grids will be written here"
    echo 
    echo " Output:"
    echo "   Series of .grd files with -180/180° longitude notation."; echo

else    
    long180_start=`date +%s`
    echo; echo "Changing longitudes to -180/180 value range ..."

    # Read attributes and setup environment
    grid_input_PATH=$1
    if [ ! -z $2 ]; then
	long180_output_PATH=$2
    else
	long180_output_PATH=$grid_input_PATH
    fi
   
    mkdir -p $long180_output_PATH
                
    if [ ! -d "$grid_input_PATH" ]; then
	echo; echo "ERROR: Directory $grid_input_PATH does not exist. Exiting ..."
    else
       
	cd $grid_input_PATH

	grid_files=($( ls *.grd ))
	if [ ${#grid_files} -eq 0 ]; then
	    echo "No grid files found in ${grid_input_PATH}. Exiting ..."
	else
	    echo "Found ${#grid_files} in $grid_input_PATH"; echo
	    for grid_file in ${grid_files[@]}; do	   
		coords=$( gmt grdinfo -I- $grid_file )
		coords=${coords:2}
		coord_array=( ${coords//\// } )
		new_lon_min=$( echo "${coord_array[0]} - 360" | bc -l )
		new_lon_max=$( echo "${coord_array[1]} - 360" | bc -l )
		echo "New longitude coordinate range for $grid_file is"
		echo "$new_lon_min - $new_lon_max"; echo
		gmt grdedit $grid_file -R${new_lon_min}/${new_lon_max}/${coord_array[2]}/${coord_array[3]} -G${long180_output_PATH}/$grid_file -V
	    done	    
	fi
    fi    
    

    long180_end=`date +%s`

    long180_runtime=$((long180_end-long180_start)) 

    printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n' $(($long180_runtime/86400)) $(($long180_runtime%86400/3600)) $(($long180_runtime%3600/60)) $(($long180_runtime%60))
    echo


fi
