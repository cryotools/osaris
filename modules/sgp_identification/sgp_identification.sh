#!/bin/bash

######################################################################
#
# OSARIS module for 'Stable Ground Point Identification' (SGPI).
#
# Calculates the sum and arithmetic mean and average of a time series
# of cohernece files.
#
# Provide a valid config file named 'sgd_identification.config' in the config
# directory; a template is provided in templates/module_config/
#
# Requires processed GMTSAR coherence files (corr_ll.grd) as input.
#
# Output files will be written to $output_PATH/SGPI:
#   - sgp_coords-F$swath.xy     -> Coordinates of max. coherence the stack
#                                 Input file for homogenize_intfs
#   - corr_sum-F$swath.grd     -> Sum of coherences from stack (grid)
#   - corr_arithmean-F$swath   -> Arith. mean of coherences (grid)
#
#
# David Loibl, 2018
#
#####################################################################

module_name="sgp_identification"

if [ ! -f "$OSARIS_PATH/config/${module_name}.config" ]; then
    echo
    echo "Cannot open ${module_name}.config in the OSARIS config folder. Please provide a valid config file."
    echo
else
    # Start runtime timer
    module_start=`date +%s`

    # Include the config file
    source $OSARIS_PATH/config/${module_name}.config



    ############################
    # Module actions start here

    echo; echo "Stable Ground Point Identification"; echo; echo
    
    sgpi_output_PATH="$output_PATH/SGPI"
    sgpi_work_PATH="$work_PATH/SGPI"

    mkdir -p $sgpi_output_PATH
    mkdir -p $sgpi_work_PATH/cut

    
    cd $sgpi_input_PATH


    for swath in ${swaths_to_process[@]}; do

	if [ -z $sgpi_region ]; then
	    echo "Obtaining minimum boundary box for corr_ll.grd files in subdirs of $sgpi_input_PATH ..."
	    boundary_box=$( $OSARIS_PATH/lib/min_grd_extent.sh corr_ll.grd $sgpi_input_PATH $swath )
	else
	    echo "Boundary box set to $sgpi_region ..."
	    boundary_box=$sgpi_region
	fi


	folders=($( ls -d *-F$swath/ ))
	sgpi_count=0
	for folder in "${folders[@]}"; do           
	    folder=${folder::-1}
	    if [ -f "$folder/corr_ll.grd" ]; then
		gmt grdcut $folder/corr_ll.grd -G$sgpi_work_PATH/cut/corr_cut_$folder.grd  -R$boundary_box -V
		gmt grdclip $sgpi_work_PATH/cut/corr_cut_$folder.grd -G$sgpi_work_PATH/cut/corr_thres_$folder.grd -Sb${sgpi_threshold}/NaN -V
		sgpi_count=$((sgpi_count+1))
	    else
		echo "No coherence file in folder $folder - skipping ..."
	    fi
	done


	cd $sgpi_work_PATH/cut
	rm corr_cut*
	cut_files=($(ls *F$swath.grd))
	cut_files_count=1
	for cut_file in "${cut_files[@]}"; do
	    if [ "$cut_files_count" -eq 1 ]; then
		if [ $debug -gt 1 ]; then echo "First file $cut_file"; fi
	    elif [ "$cut_files_count" -eq 2 ]; then	
		if [ $debug -gt 0 ]; then echo "Addition of coherence from $cut_file and $prev_cut_file ..."; fi
		gmt grdmath $cut_file $prev_cut_file ADD -V = $sgpi_work_PATH/corr_sum-F$swath.grd
	    else
		if [ $debug -gt 0 ]; then echo "Adding coherence from $cut_file ..."; fi
		gmt grdmath $cut_file $sgpi_work_PATH/corr_sum-F$swath.grd ADD -V = $sgpi_work_PATH/corr_sum-F$swath.grd
	    fi

	    prev_cut_file=$cut_file
	    cut_files_count=$((cut_files_count+1))
	done

	gmt grdmath $sgpi_work_PATH/corr_sum-F$swath.grd $sgpi_count DIV -V = $sgpi_output_PATH/corr_arithmean-F$swath.grd
	cp $sgpi_work_PATH/corr_sum-F$swath.grd $sgpi_output_PATH/corr_sum-F$swath.grd

	# Write coords of max coherence points to file for further processing ..
	gmt grdinfo -M -V $sgpi_work_PATH/corr_sum-F$swath.grd | grep z_max | awk '{ print $16,$19 }' > $sgpi_output_PATH/ps_coords-F$swath.xy
    done

    if [ $clean_up -gt 0 ]; then
	echo; echo
	echo "Cleaning up"
	rm -r $sgpi_work_PATH/cut
	echo; echo
    fi



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
