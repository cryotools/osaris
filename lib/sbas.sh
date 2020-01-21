#!/usr/bin/env bash

#################################################################
#
# Preparation of SAR data sets.
# Find matching orbits and write data.in files for each swath.
# 
# Usage: prepare_data.sh config_file
#
################################################################



if [ $# -eq 1 ]; then
    echo
    echo "Usage: prepare_data.sh config_file"  
    echo
# elif [ ! -f $1 ]; then
#     echo
#     echo "Cannot open $1. Please provide a valid config file."
#     echo
else

    echo
    echo "- - - - - - - - - - - - - - - - - - - -"
    echo " Starting data preparation ..."
    echo "- - - - - - - - - - - - - - - - - - - -"
    echo



    OSARIS_PATH="/home/loibldav/Git/osaris"
    work_PATH="/data/scratch/loibldav/GSP/Dhaka-DSC-vh/Processing"
    output_PATH="/data/scratch/loibldav/GSP/Dhaka-DSC-vh/Output"

    # ls /home/user/area/Sentinel-1/ascending/ -1 | sed -e 's/\.zip$//' > data_asc.txt
    # ls /home/user/area/Sentinel-1/ascending/ | awk '{print substr($0,18,8)}' > date_asc.txt
    # paste -d\  data_asc.txt date_asc.txt > data_asc_grub.txt

    # Date file
    date_file=$output_PATH/Reports/input_dates.list

    # Temporal baseline threshold
    temporal=100

    # Perpendicular baseline threshold
    perpendicular=100
    
    cd $work_PATH

    $OSARIS_PATH/lib/combination $date_file


    rm -f temp_bperp_combination.txt intf.in
    shopt -s extglob
    IFS=" "
    while read master slave
    do

	#calculate perpendicular baseline from combination
	dir=$(pwd)
	# cd $raw
	echo "$work_PATH/${master}--${slave}/F1/intf/"
	cd $work_PATH/${master}--${slave}/F1/intf/
	PRM_files=($( ls *PRM ))

	master=${PRM_files[0]}
	slave=${PRM_files[1]}

	echo "master: $master"
	echo "slave: $slave"
	    
    # 	SAT_baseline *$master*_ALL*.PRM *$slave*_ALL*.PRM > tmp
    # 	BPR=$(grep B_perpendicular tmp | awk '{print $3}')
    # 	#BPR2=$(echo "scale=0; $BPR" | bc)
    # 	BPR2=${BPR%.*}
    # 	rm -f tmp

    # 	cd $dir

    # 	#calculate temporal baseline from combination
    # 	master_ts=$(date -d "$master" '+%s')
    # 	slave_ts=$(date -d "$slave" '+%s')
    # 	temporal=$(echo "scale=0; ( $slave_ts - $master_ts)/(60*60*24)" | bc)

    # 	#make parameter baseline
    # 	if [ "$temporal" -lt $2 ]
    # 	then
    # 	    if [ "$BPR2" -gt -$3 ] && [ "$BPR2" -lt $3 ]
    # 	    then
    # 		echo $master $slave $temporal $BPR >> temp_bperp_combination.txt
    # 		echo "S1A"$master"_ALL_F2:S1A"$slave"_ALL_F2" >> intf.in
    # 	    fi
    # 	fi

    done < $work_PATH/result_combination.txt

    

    

fi
