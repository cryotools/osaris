#!/bin/bash

start=`date +%s`
echo
echo "- - - - - - - - - - - - - - - - - -"
echo "SLURM job EXTRACT started"
echo "- - - - - - - - - - - - - - - - - -"
echo


if [ ! $# -eq 2 ]; then
    echo
    echo "Wrong parameter count, exiting."
    echo "Usage: PP-extract file target_path"  
    echo
    exit 1
elif [ ! -f $1 ]; then
    echo
    echo "Cannot open $1. Please provide a valid zipped Sentinel1 file. Exiting."
    echo
    exit 2
else



    echo Extracting $1 ... 
    unzip $1 -x *-vh-* -d $2

    end=`date +%s`

    runtime=$((end-start))

    printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n' $(($runtime/86400)) $(($runtime%86400/3600)) $(($runtime%3600/60)) $(($runtime%60))

fi

