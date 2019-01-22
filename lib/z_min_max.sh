#!/usr/bin/env bash

######################################################################
#
# Helper tool to identify minimum and maximum values of grid files.
# Option 1: Analyse all files in a given directory.
# Option 2: Analyse all files with given file name in a series of directories.
# 
# Input:
# - Path where files reside in subdirs, e.g. Output/Pairs-forward/
# - File name, e.g. corr_ll.grd (optional, will acitvate multi-directory mode)
# - Swath number (optional to consider only specific swathes)
#
# Output:
# - String z_min z_max z_min_file z_max_file
#
#
# David Loibl, 2018
#
#####################################################################


if [ $# -lt 1 ]; then
    echo
    echo "Usage: z_min_max.sh path [file_name] [swath]"  
    echo
else
    mmz_PATH=$1

    cd $mmz_PATH
    
    mmz_count=1

    if [ $# -eq 1 ]; then
	# Analyse files in directory

	mmz_files=($( ls *.grd ))
	for mmz_file in "${mmz_files[@]}"; do   
	    if [ -f "$mmz_file" ]; then

		# Find min and max z values for a grd file.		
		
		current_file=$mmz_PATH/$mmz_file

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
    else
	# Analyse files of given name in subdirectories

	mmz_file=$2    
	swath=$3
    
    
	if [ -z $swath ]; then
	    mmz_folders=($( ls -d */ ))
	else
	    mmz_folders=($( ls -d *-F$swath/ ))
	fi

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
    fi

    echo "$z_min $z_max $z_min_file $z_max_file"

fi
