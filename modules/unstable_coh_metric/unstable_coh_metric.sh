#!/bin/bash

######################################################################
#
# Identify regions in which a coherence drop from relatively high values
# occured.
#
# Requires a file 'unstable_coh_metric.config' in the OSARIS config 
# folder containing the Slurm configuration. Get startet by copying 
# the config_template file from the templates folder and fit it to 
# your setup.
#
# David Loibl, 2018
#
#####################################################################

if [ ! -f "$OSARIS_PATH/config/unstable_coh_metric.config" ]; then
    echo
    echo "Cannot open unstable_coh_metric.config in the OSARIS config folder. Please provide a valid config file."
    echo
else

    source $OSARIS_PATH/config/unstable_coh_metric.config   
 

    rm -rf $work_PATH/UCM

    mkdir -p $work_PATH/UCM/cut_files
    mkdir -p $work_PATH/UCM/temp
    mkdir -p $output_PATH/UCM/
   
    for swath in ${swaths_to_process[@]}; do
	count=0
	mkdir -p $work_PATH/UCM/input/F$swath

	cd $output_PATH/Pairs-forward/F$swath

	folders=($( ls -r ))

	for folder in "${folders[@]}"; do
	    cp $folder/corr.grd $work_PATH/UCM/input/F$swath/corr_${folder}.grd
	done


	cd $work_PATH/UCM/input/F$swath/

	corr_files=(*.grd)
	

	for corr_file in ${corr_files[@]}; do
	    if [ "$count" -gt "0" ]; then

		# high_corr_file=HC_${corr_files[$( bc <<< $count-1 )]}

		prev_corr_file=${corr_files[$( bc <<< $count-1 )]}

		slurm_jobname="$slurm_jobname_prefix-UCM"		

		sbatch \
		    --output=$log_PATH/UCM-%j.log \
		    --error=$log_PATH/UCM-%j.log \
		    --workdir=$input_PATH \
		    --job-name=$slurm_jobname \
		    --qos=$slurm_qos \
		    --account=$slurm_account \
		    --partition=$slurm_partition \
		    --mail-type=$slurm_mailtype \
		    $OSARIS_PATH/modules/unstable_coh_metric/UCM-batch.sh \
		    $work_PATH/UCM \
		    $output_PATH/UCM \
		    $corr_file \
		    $prev_corr_file \
		    $high_corr_threshold \
		    $swath
		

	    fi
	    ((count++))
	done
    done


    $OSARIS_PATH/lib/check-queue.sh $slurm_jobname 2 0
    
    if [ $clean_up -gt 0 ]; then
	echo; echo "Cleaning up ..."
	rm -rf $work_PATH/UCM/temp/ $work_PATH/UCM/HC_*
	echo
    fi

fi
