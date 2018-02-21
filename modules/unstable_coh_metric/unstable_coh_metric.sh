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
    UCM_start_time=`date +%s`

    source $OSARIS_PATH/config/unstable_coh_metric.config   
 

    rm -rf $work_PATH/UCM

    mkdir -p $work_PATH/UCM/cut_files
    mkdir -p $work_PATH/UCM/temp
    mkdir -p $output_PATH/UCM/
   
    for swath in ${swaths_to_process[@]}; do
	count=0
	mkdir -p $work_PATH/UCM/input/F$swath

	base_PATH=$output_PATH/Pairs-forward/F$swath
	cd $base_PATH


	# Obtain minimum boundary box for corr_ll.grd files
	min_grd_extent_file=corr_ll.grd
	source $OSARIS_PATH/lib/include/min_grd_extent.sh


	folders=($( ls -d */ ))
	for folder in "${folders[@]}"; do
	    folder=${folder::-1}
	    ln -s $base_PATH/$folder/corr_ll.grd $work_PATH/UCM/input/F$swath/corr_${folder}.grd
	done


	cd $work_PATH/UCM/input/F$swath/

	corr_files=(*.grd)

	for corr_file in ${corr_files[@]}; do
	    if [ "$count" -gt "0" ]; then

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
		    $xmin/$xmax/$ymin/$ymax \
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

    
    sort $output_PATH/Reports/PP-UCM-stats.tmp > $output_PATH/Reports/PP-UCM-stats.list

    printf "\n OSARIS UCM module processing report \n \n" > $output_PATH/Reports/PP-UCM.report
    printf "Total number of pair jobs executed:\t $(cat $output_PATH/Reports/PP-UCM-stats.list | wc -l) \n \n"

    while read -r PP_job; do
	printf "Slurm job ID:\t\t $(echo $PP_job | awk '{ print $3}') \n" >> $output_PATH/Reports/PP-UCM.report
	scene_1_date=$(echo $PP_job | awk '{ print $1 }')
	scene_2_date=$(echo $PP_job | awk '{ print $2 }')
	printf "Scene dates:\t $scene_1_date $scene_2_date \n" >> $output_PATH/Reports/PP-UCM.report
	
	if [ ! "$(echo $PP_job | awk '{ print $5 }')" -eq 1 ]; then
	    printf "  Status UCM:\t failed \n" >> $output_PATH/Reports/PP-UCM.report
	else
	    printf "  Status UCM:\t ok \n" >> $output_PATH/Reports/PP-UCM.report
	fi
		
	PP_runtime=$(echo $PP_job | awk '{ print $4}')
	printf '  Processing time:\t %02dd %02dh:%02dm:%02ds\n' $(($PP_runtime/86400)) $(($PP_runtime%86400/3600)) $(($PP_runtime%3600/60)) $(($PP_runtime%60)) >> $output_PATH/Reports/PP-UCM.report
	PP_total_runtime=$((PP_total_runtime + PP_runtime))
	printf "\n \n" >> $output_PATH/Reports/PP-UCM.report
    done < "$output_PATH/Reports/PP-UCM-stats.list"
    
    rm $output_PATH/Reports/PP-UCM-stats.list $output_PATH/Reports/PP-UCM-stats.tmp

    printf '\n\nTotal processing time:\t %02dd %02dh:%02dm:%02ds\n' $(($PP_total_runtime/86400)) $(($PP_total_runtime%86400/3600)) $(($PP_total_runtime%3600/60)) $(($PP_total_runtime%60)) >> $output_PATH/Reports/PP-UCM.report
        
  
    UCM_end_time=`date +%s`
    UCM_runtime=$((UCM_end_time - UCM_start_time))

    printf 'Elapsed wall clock time:\t %02dd %02dh:%02dm:%02ds\n' $(($UCM_runtime/86400)) $(($UCM_runtime%86400/3600)) $(($UCM_runtime%3600/60)) $(($UCM_runtime%60)) >> $output_PATH/Reports/PP-UCM.report



fi
