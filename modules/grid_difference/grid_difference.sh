#!/bin/bash

######################################################################
#
# OSARIS module to calculate difference between to files in a stack
#
# Provide a valid config file named 'grid_difference.config' in the config
# directory; a template is provided in templates/module_config/
#
# Requires processed GMTSAR result files (e.g., corr_ll.grd) as input.
#
# Output files will be written to $output_PATH/Grid-difference
#
# David Loibl, 2018
#
#####################################################################


if [ ! -f "$OSARIS_PATH/config/grid_difference.config" ]; then
    echo
    echo "Cannot open grid_difference.config in the OSARIS config folder. Please provide a valid config file."
    echo
else

    source $OSARIS_PATH/config/grid_difference.config
    echo 
    echo - - - - - - - - - - - - - - - - 
    echo Calculating grid difference
    echo

    mkdir -p $output_PATH/Grid-differences
    slurm_jobname="$slurm_jobname_prefix-griddiff"

    echo "Filenames: ${grddiff_input_filenames[@]}"

    echo 
    if [ ! -z $grddiff_input_filenames ]; then
	for grddiff_input_filename in "${grddiff_input_filenames[@]}"; do
	    echo "Preparing batch jobs for $grddiff_input_filename ..."

	    for swath in ${swaths_to_process[@]}; do
		if [ ! -z $grddiff_input_PATH ] && [ -d $grddiff_input_PATH ]; then
		    echo "Input path set to $grddiff_input_PATH"
		else
		    echo "No valid input path provided, using default"
		    echo "$output_PATH/Pairs-forward"
		    grddiff_input_PATH="$output_PATH/Pairs-forward/"
		fi

		cd $grddiff_input_PATH

		folders=($( ls -d *-F$swath/ ))

		for folder in "${folders[@]}"; do
		    folder=${folder::-1}
		    echo "Adding $grddiff_input_filename from $folder ..."

		    if [ ! -z ${folder_1} ]; then
			folder_2=$folder_1
			folder_1=$folder

			grddiff_output_filename="${grddiff_input_filename::-4}--${folder_2:0:8}---${folder_1:0:8}-F${swath}"
			
			sbatch \
			    --ntasks=1 \
			    --output=$log_PATH/OSS-GrdDiff-%j-out \
			    --error=$log_PATH/OSS-GrdDiff-%j-out \
			    --workdir=$work_PATH \
			    --job-name=$slurm_jobname \
			    --qos=$slurm_qos \
			    --account=$slurm_account \
			    --mail-type=$slurm_mailtype \
			    $OSARIS_PATH/lib/difference.sh \
			    $grddiff_input_PATH/$folder_1/$grddiff_input_filename \
			    $grddiff_input_PATH/$folder_2/$grddiff_input_filename \
			    $output_PATH/Grid-difference \
			    $grddiff_output_filename \
			    0 2>&1 >>$logfile
			# TODO: Create an adequate palette for coherence differences		
			
		    else
			folder_1=$folder
		    fi
		done
	    done
	done
    else
	echo "Variable grddiff_input_filenames not set in grid_difference.config, aborting ..."
    fi

    $OSARIS_PATH/lib/check-queue.sh $slurm_jobname 1

fi
