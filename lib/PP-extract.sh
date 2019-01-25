#!/usr/bin/env bash

extract_start=`date +%s`
echo
echo "- - - - - - - - - - - - - - - - - -"
echo "SLURM job EXTRACT started"
echo "- - - - - - - - - - - - - - - - - -"
echo


if [ ! $# -eq 4 ]; then
    echo
    echo "Wrong parameter count, exiting."
    echo "Usage: PP-extract file target_path output_path"  
    echo
    exit 1
elif [ ! -f "$1/$2" ]; then
    echo
    echo "Cannot open $1. Please provide a valid zipped Sentinel1 file. Exiting."
    echo
    exit 2
else

    output_PATH=$4

    echo Extracting file $2 from folder $1 to $3 ... 
    unzip $1/$2 -x *-vh-* -d $3

    extract_end=`date +%s`

    extract_runtime=$((extract_end-extract_start))
    echo "$2 $SLURM_JOB_ID $extract_runtime" >> $output_PATH/Reports/PP-extract-stats.tmp
    printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n' $(($extract_runtime/86400)) $(($extract_runtime%86400/3600)) $(($extract_runtime%3600/60)) $(($extract_runtime%60))

fi

