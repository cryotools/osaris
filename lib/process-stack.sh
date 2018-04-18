#!/bin/bash

#################################################################
#
# Process a stack of S1 scenes.
# 
# Scenes and orbits must be available in data_swath[nr].in files
# created by prepare_data.sh. Processing of coherence and inter-
# ferograms are conducted in individual SLURM jobs for each 
# scene pair.
#
# Usage: process_stack.sh [config file]
#
################################################################

if [ $# -eq 0 ]; then
    echo
    echo "Usage: process_stack.sh config_file [supermaster]"  
    echo
elif [ ! -f $1 ]; then
    echo
    echo "Cannot open $1. Please provide a valid config file."
    echo
else

    echo
    echo "- - - - - - - - - - - - - - - - - - - -"
    echo " Starting STACK processing ..."
    echo "- - - - - - - - - - - - - - - - - - - -"
    echo

    config_file=$1
    source $config_file
    echo "Config file: $config_file"

    OSARIS_PATH=$( pwd )
    echo "GSP directory: $OSARIS_PATH"

    work_PATH=$base_PATH/$prefix/Processing
    # Path to working directory

    output_PATH=$base_PATH/$prefix/Output
    # Path to directory where all output will be written

    log_PATH=$base_PATH/$prefix/Log
    # Path to directory where the log files will be written    

    mkdir -p $work_PATH/Stack

    cd $work_PATH/raw

    echo "SWATH2PROC: $SAR_sensor"
    printf '%s\n' "${swath_to_process[@]}"
    echo $swath_to_process

    for swath in ${swaths_to_process[@]}; do
	
	echo "SWATH: $swath"
	echo - - - - - - - - - - - - - - - - 
	echo "Launching SLURM batch jobs"
	echo
	echo "Processing logs will be written to $log_PATH"
	echo "Use tail -f [logfile] to monitor the SLURM tasks"
	echo
	
	slurm_jobname="$slurm_jobname_prefix-stack"

	sbatch \
	    --ntasks=10 \
	    --output=$log_PATH/GSP-%j-stack \
	    --error=$log_PATH/GSP-%j-stack \
	    --workdir=$work_PATH \
	    --job-name=$slurm_jobname \
	    --qos=$slurm_qos \
	    --account=$slurm_account \
	    --partition=$slurm_partition \
	    --mail-type=$slurm_mailtype \
	    $OSARIS_PATH/lib/PP-stack.sh \
	    data_swath$swath.in \
	    $config_file \
	    $OSARIS_PATH/$gmtsar_config_file \
	    $OSARIS_PATH
	
	
    done  
fi

