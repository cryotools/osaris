#!/usr/bin/env bash

######################################################################
#
# OSARIS module for 'Stable Ground Point Identification' (SGPI).
#
# Calculates the sum and arithmetic mean of a time series of cohernece files.
#
# Provide a valid config file named 'sgp_identification.config' in the config
# directory; a template is provided in templates/module_config/
#
# Requires processed GMTSAR coherence files (corr_ll.grd) as input.
#
# Output files will be written to $output_PATH/SGPI:
#   - sgp-coords.xy    -> Coordinates of max. coherence the stack.
#                                 Input file for other modules, including
#                                 'Harmonize Grids' and 'GACOS Correction'
#   - coherence-sum.grd     -> Sum of coherences from stack (grid)
#   - cohehernce-arithmean.grd   -> Arith. mean of coherences (grid)
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


    # Handle boundary box
    if [ -z $sgpi_region ]; then
	echo "Obtaining minimum boundary box from files in $sgpi_input_PATH ..."
	boundary_box=$( $OSARIS_PATH/lib/min_grd_extent.sh $sgpi_input_PATH )
    else
	echo "Boundary box set to $sgpi_region ..."
	boundary_box=$sgpi_region
    fi


    # Cut input files to boundary box extent
    coh_files=($( ls *.grd ))
    for coh_file in ${coh_files[@]}; do
	gmt grdcut $coh_file -G$sgpi_work_PATH/cut/${coh_file::-4}-cut.grd  -R$boundary_box -V
	gmt grdclip $sgpi_work_PATH/cut/${coh_file::-4}-cut.grd -G$sgpi_work_PATH/cut/${coh_file::-4}-cut-thres.grd -Sb${sgpi_threshold}/NaN -V
    done


    # Calculate sum of coherence from all files
    cd $sgpi_work_PATH/cut
    rm *-cut.grd
    cut_files=($(ls *.grd))
    cut_files_count=0
    for cut_file in "${cut_files[@]}"; do
	if [ "$cut_files_count" -eq 0 ]; then
	    if [ $debug -gt 1 ]; then echo "First file $cut_file"; fi
	    cp $cut_file $sgpi_work_PATH/coherence-sum.grd
	# elif [ "$cut_files_count" -eq 2 ]; then	
	#     if [ $debug -gt 0 ]; then echo "Addition of coherence from $cut_file and $prev_cut_file ..."; fi
	#     gmt grdmath $cut_file $prev_cut_file ADD -V = $sgpi_work_PATH/coherence-sum.grd
	else
	    if [ $debug -gt 0 ]; then echo "Adding coherence from $cut_file ..."; fi
	    gmt grdmath $cut_file $sgpi_work_PATH/coherence-sum.grd ADD -V = $sgpi_work_PATH/coherence-sum.grd
	fi

	# prev_cut_file=$cut_file
	cut_files_count=$((cut_files_count+1))
    done

    # Calculate the arithmetic mean of all coherences files
    gmt grdmath $sgpi_work_PATH/coherence-sum.grd $cut_files_count DIV -V = $sgpi_output_PATH/coherence-arithmean.grd
    cp $sgpi_work_PATH/coherence-sum.grd $sgpi_output_PATH/coherence-sum.grd

    # Write coords of max coherence points to file for further processing ..
    gmt grdinfo -M -V $sgpi_work_PATH/coherence-sum.grd | grep z_max | awk '{ print $16,$19 }' > $sgpi_output_PATH/sgp-coords.xy


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
