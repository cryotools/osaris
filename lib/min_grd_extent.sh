#!/bin/bash

######################################################################
#
# Helper tool to identify a boundary box that represents the minimum
# common coverage of a set of grid files.
# 
# Input:
# - Path where files reside in subdirs, e.g. Output/Pairs-forward/
# - File name, e.g. corr_ll.grd
# - Swath number (optional to consider only specific swathes)
#
# Output:
# - String x_min x_max y_min y_max
#
#
# David Loibl, 2018
#
#####################################################################


if [ $# -lt 2 ]; then
    echo
    echo "Usage: min_grd_extent.sh file_name path [swath]"  
    echo
else
    min_ext_file=$1
    min_ext_PATH=$2
    swath=$3

    cd $min_ext_PATH

    if [ -z $swath ]; then
	min_ext_folders=($( ls -d */ ))
    else
	min_ext_folders=($( ls -d *-F$swath/ ))
    fi

    min_ext_count=1

    for folder in "${min_ext_folders[@]}"; do   
	folder=${folder::-1}
	if [ -f "$folder/$min_ext_file" ]; then
	    if [ "$min_ext_count" -eq 1 ]; then		
		:
	    elif [ "$min_ext_count" -eq 2 ]; then
		# echo "grdxtremes=($(grdminmax $min_ext_PATH/$prev_folder/$min_ext_file $min_ext_PATH/$folder/$min_ext_file))"


		# Find min and max x and y values for a grd file.
		# Input parameters: the two grd files to evaluate.
		# Output: xmin xmax ymin ymax

		file_1=$min_ext_PATH/$prev_folder/$min_ext_file
		file_2=$min_ext_PATH/$folder/$min_ext_file

		file_1_extent=$( gmt grdinfo -I- $file_1 ); file_1_extent=${file_1_extent:2}
		file_2_extent=$( gmt grdinfo -I- $file_2 ); file_2_extent=${file_2_extent:2}

		file_1_coord_string=$( echo $file_1_extent | tr "/" "\n")
		file_2_coord_string=$( echo $file_2_extent | tr "/" "\n")

		# Create arrays of coordinates for each dataset
		counter=0
		for coord in $file_1_coord_string; do
		    file_1_coord_array[$counter]=$coord
		    counter=$((counter+1))
		done

		counter=0
		for coord in $file_2_coord_string; do
		    file_2_coord_array[$counter]=$coord
		    counter=$((counter+1))
		done
		

		# Determine overal max and min values for both datasets

		remainder=$( expr $counter % 2 )

		counter=0
		while [ $counter -lt 4 ]; do    
		    if [ $counter -eq 0 ]; then
			# Determining xmin
			if [ $( echo "${file_1_coord_array[$counter]} > ${file_2_coord_array[$counter]}" | bc -l ) -eq 0 ]; then
			    xmin=${file_2_coord_array[$counter]}
			else
			    xmin=${file_1_coord_array[$counter]}
			fi
		    elif [ $counter -eq 1 ]; then
			# Determining xmax
			if [ $( echo "${file_1_coord_array[$counter]} < ${file_2_coord_array[$counter]}" | bc -l ) -eq 0 ]; then
			    xmax=${file_2_coord_array[$counter]}
			else
			    xmax=${file_1_coord_array[$counter]}
			fi
		    elif [ $counter -eq 2 ]; then
			# Determining ymin 
			if [ $( echo "${file_1_coord_array[$counter]} > ${file_2_coord_array[$counter]}" | bc -l ) -eq 0 ]; then
			    ymin=${file_2_coord_array[$counter]}
			else
			    ymin=${file_1_coord_array[$counter]}
			fi
		    elif [ $counter -eq 3 ]; then
			# Determining ymax 
			if [ $( echo "${file_1_coord_array[$counter]} < ${file_2_coord_array[$counter]}" | bc -l ) -eq 0 ]; then
			    ymax=${file_2_coord_array[$counter]}
			else
			    ymax=${file_1_coord_array[$counter]}
			fi
		    fi

		    counter=$((counter+1))
		done	

	    else

		# Find min and max x and y values for a grd file.
		# Input parameters: the two grd files to evaluate.
		# Output: xmin xmax ymin ymax

		file_1=$min_ext_PATH/$prev_folder/$min_ext_file
		file_2=$min_ext_PATH/$folder/$min_ext_file

		file_1_extent=$( gmt grdinfo -I- $file_1 ); file_1_extent=${file_1_extent:2}
		file_2_extent=$( gmt grdinfo -I- $file_2 ); file_2_extent=${file_2_extent:2}

		file_1_coord_string=$( echo $file_1_extent | tr "/" "\n")
		file_2_coord_string=$( echo $file_2_extent | tr "/" "\n")

		# Create arrays of coordinates for each dataset
		counter=0
		for coord in $file_1_coord_string; do
		    file_1_coord_array[$counter]=$coord
		    counter=$((counter+1))
		done

		counter=0
		for coord in $file_2_coord_string; do
		    file_2_coord_array[$counter]=$coord
		    counter=$((counter+1))
		done
		
		# Determine overal max and min values for both datasets

		remainder=$( expr $counter % 2 )

		counter=0
		while [ $counter -lt 4 ]; do    
		    if [ $counter -eq 0 ]; then
			# Determining xmin
			if [ $( echo "${file_1_coord_array[$counter]} > ${file_2_coord_array[$counter]}" | bc -l ) -eq 0 ]; then
			    xmin_local=${file_2_coord_array[$counter]}
			else
			    xmin_local=${file_1_coord_array[$counter]}
			fi
		    elif [ $counter -eq 1 ]; then
			# Determining xmax
			if [ $( echo "${file_1_coord_array[$counter]} < ${file_2_coord_array[$counter]}" | bc -l ) -eq 0 ]; then
			    xmax_local=${file_2_coord_array[$counter]}
			else
			    xmax_local=${file_1_coord_array[$counter]}
			fi
		    elif [ $counter -eq 2 ]; then
			# Determining ymin 
			if [ $( bc <<< "${file_1_coord_array[$counter]} > ${file_2_coord_array[$counter]}" ) -eq 0 ]; then
			    ymin_local=${file_2_coord_array[$counter]}
			else
			    ymin_local=${file_1_coord_array[$counter]}
			fi
		    elif [ $counter -eq 3 ]; then
			# Determining ymax 
			if [ $( bc <<< "${file_1_coord_array[$counter]} < ${file_2_coord_array[$counter]}" ) -eq 0 ]; then
			    ymax_local=${file_2_coord_array[$counter]}
			else
			    ymax_local=${file_1_coord_array[$counter]}
			fi
		    fi

		    counter=$((counter+1))
		done
		
		if (( $(echo "$xmin < $xmin_local" | bc -l) ))  && (( $(echo "$xmin_local != 0" | bc -l) )); then 
		    xmin=$xmin_local 
		fi
		if (( $(echo "$xmax > $xmax_local" | bc -l) ))  && (( $(echo "$xmax_local != 0" | bc -l) )); then 
		    xmax=$xmax_local 
		fi
		if (( $(echo "$ymin < $ymin_local" | bc -l) ))  && (( $(echo "$ymin_local != 0" | bc -l) )); then 	
		    ymin=$ymin_local 
		fi
		if (( $(echo "$ymax > $ymax_local" | bc -l) ))  && (( $(echo "$ymax_local != 0" | bc -l) )); then 		
		    ymax=$ymax_local
		fi

		
	    fi
	    
	    

	    prev_folder=$folder
	    min_ext_count=$((min_ext_count+1))
	# else
	    # echo "No coherence file in folder $folder - skipping ..."
	fi
    done

    # if [ $debug -gt 0 ]; then echo; echo "Common coverage boundary box: $xmin/$xmax/$ymin/$ymax"; fi
    echo "$xmin/$xmax/$ymin/$ymax"

fi
