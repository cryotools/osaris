#!/bin/bash

######################################################################
#
# OSARIS module to identify persitent scatterers (simple)
#
# Provide a valid config file named 'simple_psi.config' in the config
# directory; a template is provided in templates/module_config/
#
# Requires processed GMTSAR coherence files (corr_ll.grd) as input.
#
# Output files will be written to $output_PATH/PSI:
#   - ps_coords-F$swath.xy     -> Coordinates of max. coherence the stack
#                                 Input file for homogenize_intfs
#   - corr_sum-F$swath.grd     -> Sum of coherences from stack (grid)
#   - corr_arithmean-F$swath   -> Arith. mean of coherences (grid)
#
# David Loibl, 2018
#
#####################################################################


if [ ! -f "$OSARIS_PATH/config/simple_psi.config" ]; then
    echo
    echo "Cannot open simple_psi.config in the OSARIS config folder. Please provide a valid config file."
    echo
else
    SPSI_start_time=`date +%s`

    source $OSARIS_PATH/config/simple_psi.config   

    psi_output_PATH="$output_PATH/PSI"

    echo; echo "Simple Persistent Scatterer Identification"

    mkdir -p $psi_output_PATH/cut

    cd $psi_input_PATH


    for swath in ${swaths_to_process[@]}; do

	if [ -z $psi_region ]; then
	    echo "Obtaining minimum boundary box for corr_ll.grd files in subdirs of $psi_input_PATH ..."
	    boundary_box=$( $OSARIS_PATH/lib/min_grd_extent.sh corr_ll.grd $psi_input_PATH $swath )
	else
	    echo "Boundary box set to $psi_region ..."
	    boundary_box=$psi_region
	fi


	folders=($( ls -d *-F$swath/ ))
	psi_count=0
	for folder in "${folders[@]}"; do           
	    folder=${folder::-1}
	    if [ -f "$folder/corr_ll.grd" ]; then
		gmt grdcut $folder/corr_ll.grd -G$psi_output_PATH/cut/corr_cut_$folder.grd  -R$boundary_box -V
		gmt grdclip $psi_output_PATH/cut/corr_cut_$folder.grd -G$psi_output_PATH/cut/corr_thres_$folder.grd -Sb${psi_threshold}/NaN -V
		psi_count=$((psi_count+1))
	    else
		echo "No coherence file in folder $folder - skipping ..."
	    fi
	done


	cd $psi_output_PATH/cut
	rm corr_cut*
	cut_files=($(ls *F$swath.grd))
	cut_files_count=1
	for cut_file in "${cut_files[@]}"; do
	    if [ "$cut_files_count" -eq 1 ]; then
		if [ $debug -gt 1 ]; then echo "First file $cut_file"; fi
	    elif [ "$cut_files_count" -eq 2 ]; then	
		if [ $debug -gt 0 ]; then echo "Addition of coherence from $cut_file and $prev_cut_file ..."; fi
		gmt grdmath $cut_file $prev_cut_file ADD -V = $psi_output_PATH/corr_sum-F$swath.grd
	    else
		if [ $debug -gt 0 ]; then echo "Adding coherence from $cut_file ..."; fi
		gmt grdmath $cut_file $psi_output_PATH/corr_sum-F$swath.grd ADD -V = $psi_output_PATH/corr_sum-F$swath.grd
	    fi

	    prev_cut_file=$cut_file
	    cut_files_count=$((cut_files_count+1))
	done

	gmt grdmath $psi_output_PATH/corr_sum-F$swath.grd $psi_count DIV -V = $psi_output_PATH/corr_arithmean-F$swath.grd 

	# Write coords of max coherence points to file for further processing ..
	gmt grdinfo -M -V $psi_output_PATH/corr_sum-F$swath.grd | grep z_max | awk '{ print $16,$19 }' > $psi_output_PATH/ps_coords-F$swath.xy
    done

    if [ $clean_up -gt 0 ]; then
	echo; echo
	echo "Cleaning up"
	rm -r $psi_output_PATH/cut
	echo; echo
    fi

    SPSI_end_time=`date +%s`

    SPSI_runtime=$((SPSI_end_time - SPSI_start_time))

    printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n' $(($SPSI_runtime/86400)) $(($SPSI_runtime%86400/3600)) $(($SPSI_runtime%3600/60)) $(($SPSI_runtime%60))
    echo


fi
