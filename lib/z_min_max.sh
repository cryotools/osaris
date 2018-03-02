#!/bin/bash

######################################################################
#
# Helper tool to identify minimum and maximum values of files with the
# same file name in a series of directories.
# 
# Input:
# - Path where files reside in subdirs, e.g. Output/Pairs-forward/
# - File name, e.g. corr_ll.grd
# - Swath number (optional to consider only specific swathes)
#
# Output:
# - String z_min z_max z_min_file z_max_file
#
#
# David Loibl, 2018
#
#####################################################################


if [ $# -lt 2 ]; then
    echo
    echo "Usage: z_min_max.sh file_name path [swath]"  
    echo
else
    mmz_file=$1
    mmz_PATH=$2
    swath=$3
    
    cd $mmz_PATH
    if [ -z $swath ]; then
	mmz_folders=($( ls -d */ ))
    else
	mmz_folders=($( ls -d *-F$swath/ ))
    fi

    mmz_count=1


    for folder in "${mmz_folders[@]}"; do   
	folder=${folder::-1}
	if [ -f "$folder/$mmz_file" ]; then

	    # Find min and max z values for a grd file.		
	    
	    current_file=$mmz_PATH/$folder/$mmz_file

	    current_z_min=$( gmt grdinfo $current_file | grep z_min | awk '{ print $3}' )
	    current_z_max=$( gmt grdinfo $current_file | grep z_min | awk '{ print $5}' )

	    if [ "$mmz_count" -eq 1 ]; then
		# First round, set min and max values to values from file
		z_min=$current_z_min
		z_max=$current_z_max
		z_min_file=$current_file
		z_max_file=$current_file
	    else
		# Iteration, check if min/max from file are smaller/larger than previous ...
		if [ $( echo "$current_z_min < $z_min" | bc -l ) -eq 1 ]; then 
		    z_min=$current_z_min
		    z_min_file=$current_file			
		fi

		if [ $( echo "$current_z_max > $z_max" | bc -l ) -eq 1 ]; then 
		    z_max=$current_z_max
		    z_max_file=$current_file
		fi
	    fi
    
	    mmz_count=$((mmz_count+1))
	    	
	fi
    done

    echo "$z_min $z_max $z_min_file $z_max_file"

    # if [ $debug -gt 0 ]; then 
    # 	echo; echo "Overall min/max z values: $z_min/$z_max"; 
    # 	echo "Min z was found in file $z_min_file"; 
    # 	echo "Max z was found in file $z_max_file" 
    # fi
    # cd $mmz_base_PATH

fi
