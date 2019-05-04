#!/usr/bin/env bash

extract_start=`date +%s`
echo
echo "- - - - - - - - - - - - - - - - - -"
echo "SLURM job EXTRACT started"
echo "- - - - - - - - - - - - - - - - - -"
echo


if [ ! $# -eq 5 ]; then
    echo
    echo "Wrong parameter count, exiting."
    echo "Usage: PP-extract file target_path output_path polarization"  
    echo
    exit 1
elif [ ! -f "$1/$2" ]; then
    echo
    echo "Cannot open $1. Please provide a valid zipped Sentinel1 file. Exiting."
    echo
    exit 2
else
    # $OSARIS_PATH/lib/PP-extract.sh $input_PATH $S1_archive $work_PATH/orig $output_PATH $polarization
    input_PATH=$1
    S1_archive=$2
    S1_output_PATH=$3
    output_PATH=$4
    polarization=$5
    
    echo "Extracting file $S1_archive from directory $input_PATH to $S1_output_PATH ..."
    if [ "$polarization" = "vv" ]; then
	pol_exclude="-x *-vh-*"
    elif [ "$polarization" = "vh" ]; then
	pol_exclude="-x *-vv-*"
    elif [ "$polarization" = "both" ]; then
	pol_exclude=""
    else
	pol_exclude="-x *-vh-*"
    fi
    
    unzip $input_PATH/$S1_archive $pol_exclude -d $S1_output_PATH

    extract_end=`date +%s`

    extract_runtime=$((extract_end-extract_start))
    echo "$2 $SLURM_JOB_ID $extract_runtime" >> $output_PATH/Reports/PP-extract-stats.tmp
    printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n' $(($extract_runtime/86400)) $(($extract_runtime%86400/3600)) $(($extract_runtime%3600/60)) $(($extract_runtime%60))

fi

