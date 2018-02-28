#!/bin/bash

######################################################################
#
# Sniplet to identify a boundary box that represents the minimum
# common coverage of a set of grid files.
# 
# The script must be invoked from a directory which contains
# subdirectories in which the grid files reside, e.g. 
# Output/Pairs-forward/F1/
#
# The filename to consider must be set in the invoking script, e.g.
# min_grd_extent_file=corr_ll.grd
#
# Include to a script using:
# source $OSARIS_PATH/lib/include/min_grd_extent.sh
# 
# Output:
# The boundary box indicated by four vars
# $xmin, $xmax, $ymin, $ymax
#
#
# David Loibl, 2018
#
#####################################################################



if [ -z $min_grd_extent_file ]; then
    echo "Variable min_grd_extent_file is not set but mandatory for min_grd_extent.sh. Skipping ..."
else

    mge_base_PATH=$(pwd)
    
    if [ -z $swath ]; then
	mge_folders=($( ls -d */ ))
    else
	mge_folders=($( ls -d *-F$swath/ ))
    fi

    mge_count=1


    for folder in "${mge_folders[@]}"; do   
	folder=${folder::-1}
	if [ -f "$folder/$min_grd_extent_file" ]; then
	    if [ "$mge_count" -eq 1 ]; then
		echo "First folder $folder"
	    elif [ "$mge_count" -eq 2 ]; then

		# Find min and max x and y values for a grd file.
		# Input parameters: the two grd files to evaluate.
		# Output: xmin xmax ymin ymax

		file_1=$mge_base_PATH/$prev_folder/$min_grd_extent_file
		file_2=$mge_base_PATH/$folder/$min_grd_extent_file

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
		if [ $debug -gt 0 ]; then echo "Initial coord set: $xmin/$xmax/$ymin/$ymax"; fi

	    else

		# Find min and max x and y values for a grd file.
		# Input parameters: the two grd files to evaluate.
		# Output: xmin xmax ymin ymax

		file_1=$mge_base_PATH/$prev_folder/$min_grd_extent_file
		file_2=$mge_base_PATH/$folder/$min_grd_extent_file

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
		    if [ $debug -gt 0 ]; then echo "New xmin value found: $xmin_local"; fi
		    xmin=$xmin_local 
		fi
		if (( $(echo "$xmax > $xmax_local" | bc -l) ))  && (( $(echo "$xmax_local != 0" | bc -l) )); then 
		    if [ $debug -gt 0 ]; then echo "New xmax value found: $xmax_local"; fi
		    xmax=$xmax_local 
		fi
		if (( $(echo "$ymin < $ymin_local" | bc -l) ))  && (( $(echo "$ymin_local != 0" | bc -l) )); then 
		    if [ $debug -gt 0 ]; then echo "New ymin value found: $ymin_local"; fi
		    ymin=$ymin_local 
		fi
		if (( $(echo "$ymax > $ymax_local" | bc -l) ))  && (( $(echo "$ymax_local != 0" | bc -l) )); then 
		    if [ $debug -gt 0 ]; then echo "New ymax value found: $ymax_local"; fi
		    ymax=$ymax_local
		fi

		if [ $debug -gt 0 ]; then echo "Updated coord set: $xmin/$xmax/$ymin/$ymax"; fi
	    fi
	    
	    

	    prev_folder=$folder
	    mge_count=$((mge_count+1))
	else
	    echo "No coherence file in folder $folder - skipping ..."
	fi
    done

    if [ $debug -gt 0 ]; then echo; echo "Common coverage boundary box: $xmin/$xmax/$ymin/$ymax"; fi
    cd $mge_base_PATH

fi
