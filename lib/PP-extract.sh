#!/bin/bash

start=`date +%s`
echo
echo "- - - - - - - - - - - - - - - - - -"
echo "SLURM job EXTRACT started"
echo "- - - - - - - - - - - - - - - - - -"
echo


if [ ! $# -eq 3 ]; then
    echo
    echo "Wrong parameter count, exiting."
    echo "Usage: PP-extract file target_path"  
    echo
    exit 1
elif [ ! -f "$1/$2" ]; then
    echo
    echo "Cannot open $1. Please provide a valid zipped Sentinel1 file. Exiting."
    echo
    exit 2
else



    echo Extracting file $2 from folder $1 to $3 ... 
    unzip $1/$2 -x *-vh-* -d $3

    end=`date +%s`

    runtime=$((end-start))

    printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n' $(($runtime/86400)) $(($runtime%86400/3600)) $(($runtime%3600/60)) $(($runtime%60))

fi

