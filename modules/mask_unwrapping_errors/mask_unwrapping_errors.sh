#!/usr/bin/env bash

######################################################################
#
# Mask unwrapping errors based on comparison of forward to reverse
# pairs of unwrapped interferograms.
#
# Requires activation of reverse interferogram processing in the main
# configuration file.
#
# David Loibl, 2018
#
#####################################################################

module_name="mask_unwrapping_errors"

if [ ! -f "$OSARIS_PATH/config/${module_name}.config" ]; then
    echo
    echo "Cannot open ${module_name}.config in the OSARIS config folder. Please provide a valid config file."
    echo
else
    # Start runtime timer
    module_start=`date +%s`

    # Include the config file
    source $OSARIS_PATH/config/${module_name}.config

    # MUE_input_PATH="$output_PATH/GACOS-corrected"
    # MUE_fwdrev_sums_PATH="$output_PATH/Unwrapping-sums"
    # MUE_threshold="0.1"

    # Read attributes and setup environment
    
    MUE_work_PATH="$work_PATH/Mask-unwrapping-errors"
    MUE_output_PATH="$output_PATH/Masked-unwrapping-errors"
    
    mkdir -p $MUE_output_PATH
    mkdir -p $MUE_work_PATH
    
    echo; echo "PATHES:"
    echo "MUE_input_PATH: $MUE_input_PATH"
    echo "MUE_fwdrev_sums_PATH: $MUE_fwdrev_sums_PATH"    
    echo "MUE_work_PATH: $MUE_work_PATH"
    echo "MUE_output_PATH: $MUE_output_PATH"

    echo; echo "MUE_threshold: $MUE_threshold"
    echo
    
    cd "$MUE_fwdrev_sums_PATH"
    
    unwrp_sums_grds=($( ls *.grd ))
    
    for grd_file in ${unwrp_sums_grds[@]}; do
	
	echo; echo "Now working on $grd_file .."
	# Cut unwrapped interferogram and masked fwd-rev-unwrapping sum to same extent
	
	cd "$MUE_input_PATH"
	echo "Searching for: ${grd_file:0:8}--${grd_file:10:8}*.grd"
	echo "in directory $MUE_input_PATH"
	echo; echo "FWD-REV PATH: $MUE_fwdrev_sums_PATH"

	input_match=$( ls ${grd_file:0:8}--${grd_file:10:8}*.grd )
	
	if [ ! -f "$input_match" ]; then
	    echo "No matching unwrapped interferogram found for ${grd_file}. Skipping ..."
	else
	    cd "$MUE_fwdrev_sums_PATH"
	    # $MUE_threshold

	    # Create the mask basing on thresholds of deviation in fwd-rev unwrapping sums
	    gmt grdmath ${MUE_fwdrev_sums_PATH}/${grd_file} -$MUE_threshold LT 1 NAN = ${MUE_work_PATH}/${grd_file::-4}-min-masked.grd -V
	    gmt grdmath ${MUE_fwdrev_sums_PATH}/${grd_file} $MUE_threshold GT 1 NAN = ${MUE_work_PATH}/${grd_file::-4}-max-masked.grd -V
	    # gmt grdmath ${MUE_work_PATH}/${grd_file::-4}-min-masked.grd  GT 1 NAN = ${MUE_work_PATH}/${grd_file::-4}-masked.grd -V
	    gmt grdmath ${MUE_work_PATH}/${grd_file::-4}-min-masked.grd ${MUE_work_PATH}/${grd_file::-4}-max-masked.grd ADD = ${MUE_work_PATH}/${grd_file::-4}-masked.grd -V
	    
	    file_1="${MUE_work_PATH}/${grd_file::-4}-masked.grd"
	    file_2="$MUE_input_PATH/$input_match"

	    file_1_extent=$( gmt grdinfo -I- $file_1 ); file_1_extent=${file_1_extent:2}
	    file_2_extent=$( gmt grdinfo -I- $file_2 ); file_2_extent=${file_2_extent:2}

	    file_1_coord_string=$( echo $file_1_extent | tr "/" "\n")
	    file_2_coord_string=$( echo $file_2_extent | tr "/" "\n")

	    echo; echo "File 1 coordinate string: "
	    echo "$file_1_coord_string"
	    echo; echo "File 2 coordinate string: "
	    echo "$file_2_coord_string"	    
	    
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
	    
	    echo "Minimum boundary box coordinates (xmin/xmax/ymin/ymax):"
	    echo "$xmin/$xmax/$ymin/$ymax"
	    
	    gmt grdsample ${MUE_input_PATH}/${input_match} -G${MUE_work_PATH}/${input_match::-4}-cut.grd -R$xmin/$xmax/$ymin/$ymax `gmt grdinfo -I ${MUE_work_PATH}/${grd_file::-4}-masked.grd` -V
	    gmt grdsample ${MUE_work_PATH}/${grd_file::-4}-masked.grd  -G${MUE_work_PATH}/${grd_file::-4}-cut.grd -R$xmin/$xmax/$ymin/$ymax `gmt grdinfo -I ${MUE_work_PATH}/${input_match::-4}-cut.grd` -V
	    gmt grdmath ${MUE_work_PATH}/${input_match::-4}-cut.grd ${MUE_work_PATH}/${grd_file::-4}-cut.grd ADD = ${MUE_output_PATH}/${input_match::-4}-masked.grd -V
	fi	

    done








    # Stop runtime timer and print runtime
    module_end=`date +%s`    
    module_runtime=$((module_end-module_start))

    echo
    printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n\n' \
	$(($module_runtime/86400)) \
	$(($module_runtime%86400/3600)) \
	$(($module_runtime%3600/60)) \
	$(($module_runtime%60))
    echo
fi
