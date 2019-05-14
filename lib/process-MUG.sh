#!/usr/bin/env bash

#################################################################
#
# Merge, unwrap and geocode multiple swaths
# 
#
# Usage: process-multi-swath.sh config_file
#
#
################################################################

if [ $# -eq 0 ]; then
    echo
    echo "Usage: process-multi-swath.sh config_file"  
    echo
elif [ ! -f $1 ]; then
    echo
    echo "Cannot open $1. Please provide a valid config file."
    echo
else

    echo
    echo "- - - - - - - - - - - - - - - - - - - -"
    echo " Starting multi-swath processing ..."
    echo "- - - - - - - - - - - - - - - - - - - -"
    echo

    config_file=$1
    source $config_file
    echo "Config file: $config_file"

    OSARIS_PATH=$( pwd )

    work_PATH=$base_PATH/$prefix/Processing
    # Path to working directory

    output_PATH=$base_PATH/$prefix/Output
    # Path to directory where all output will be written

    log_PATH=$base_PATH/$prefix/Log
    # Path to directory where the log files will be written    



    cd $work_PATH
    mkdir -p merge-files
    
    s1_pairs=($( ls -d *20*/ ))
    if [ -f $work_PATH/pairs-forward.list ]; then pairs_forward=($( cat $work_PATH/pairs-forward.list )); fi
    if [ -f $work_PATH/pairs-reverse.list ]; then pairs_reverse=($( cat $work_PATH/pairs-reverse.list )); fi
    

    slurm_jobname="$slurm_jobname_prefix-MSP"

    for s1_pair in ${s1_pairs[@]}; do	
	s1_pair=${s1_pair::-1}
	echo; echo "Preparing Slurm batch jobs for $s1_pair"

	if [[ " ${pairs_forward[@]} " =~ " ${s1_pair} " ]]; then
	    direction="forward"
	    if [ $debug -ge 1 ]; then echo "Forward scene pair"; fi
	elif [[ " ${pairs_reverse[@]} " =~ " ${s1_pair} " ]]; then
	    direction="reverse"
	    if [ $debug -ge 1 ]; then echo "Reverse scene pair"; fi
	else
	    if [ $debug -ge 1 ]; then echo "Scene pair found in neither forward nor reverse list. Strange."; fi
	fi

	ln -s $work_PATH/topo/dem.grd $work_PATH/$s1_pair

	master_date=${s1_pair:0:8}
	slave_date=${s1_pair:10:8}	
	
	mkdir -p $work_PATH/${s1_pair}/merged

	#for swath in ${swaths_to_process[@]}; do
	# s1_code=$( ls -d */ | head -n1 )
	# s1_code=${s1_code::-1}
	# cd $s1_code

	cd $work_PATH/${s1_pair}
	swath_dirs=$( ls -d *F* )

	if [ $debug -ge 1 ]; then
	    echo "Swath directories found for ${s1_pair}: ${swath_dirs[@]}"
	fi

	for swath_dir in ${swath_dirs[@]}; do
	    if [ -d $swath_dir/intf ]; then
		cd $swath_dir/intf
		master_PRM=$( ls *${master_date}*.PRM )
		slave_PRM=$( ls *${slave_date}*.PRM )	    
		echo "$swath_dir/intf/:${master_PRM}:${slave_PRM}" >> $work_PATH/merge-files/${s1_pair}.list #${s1_code}/
	    fi
	done

	# Setup preferred and alternative partition configuration
	slurm_partition_pref=$slurm_partition
	slurm_ntasks_pref=$slurm_ntasks

	if [ ! -z $slurm_partition_alt ] && [ ! -z $slurm_ntasks_alt ]; then
	    # Check for available cores on the preferred slurm partition.
	    sleep 2
	    cores_available=$( sinfo -o "%P %C" | grep $slurm_partition | awk '{ print $2 }' | awk 'BEGIN { FS="/?[ \t]*"; } { print $2 }' )
	    echo "Cores available on partition ${slurm_partition}: $cores_available"
	    if [ "$cores_available" -lt "$slurm_ntasks" ]; then
		slurm_partition_pref=$slurm_partition_alt
		slurm_ntasks_pref=$slurm_ntasks_alt
	    fi
	fi

	sbatch \
    	    --ntasks=$slurm_ntasks_pref \
    	    --output=$log_PATH/PP-MUG-%j-out \
    	    --error=$log_PATH/PP-MUG-%j-out \
    	    --workdir=$work_PATH \
    	    --job-name=$slurm_jobname \
    	    --qos=$slurm_qos \
    	    --account=$slurm_account \
    	    --partition=$slurm_partition_pref \
    	    --mail-type=$slurm_mailtype \
    	    $OSARIS_PATH/lib/PP-MUG.sh \
    	    $s1_pair \
    	    $config_file \
    	    $OSARIS_PATH/$gmtsar_config_file \
    	    $OSARIS_PATH \
	    $direction

	# step 3: launch PP jobs
	cd $work_PATH
    done



fi

