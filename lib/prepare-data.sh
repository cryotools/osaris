#!/bin/bash

#################################################################
#
# Preparation of SAR data sets.
# Find matching orbits and write data.in files for each swath.
# 
# Usage: prepare_data.sh config_file
#
################################################################


if [ $# -eq 0 ]; then
    echo
    echo "Usage: prepare_data.sh config_file"  
    echo
elif [ ! -f $1 ]; then
    echo
    echo "Cannot open $1. Please provide a valid config file."
    echo
else

    echo
    echo "- - - - - - - - - - - - - - - - - - - -"
    echo " Starting data preparation ..."
    echo "- - - - - - - - - - - - - - - - - - - -"
    echo

    config_file=$1
    echo "config file: $config_file"
    source $config_file
    
    OSARIS_PATH=$( pwd )

    work_PATH=$base_PATH/$prefix/Processing
    # Path to working directory

    log_PATH=$base_PATH/$prefix/Log
    # Path to directory where the log files will be written    
    
    cd $work_PATH/orig

    counter=1
    
    for S1_package in $( ls -r ); do	    
        #echo tar xvf $i -C $work_PATH
        
        #echo ${S1_package:0:${#S1_package}-4}
        S1_file[$counter]=${S1_package:0:${#S1_package}-4}
        #echo ${S1_package:17:8}
        S1_date[$counter]=${S1_package:17:8}
        
	if [ "$debug" -ge 1 ]; then
	    echo
	    echo Opening SAFE file: 
	    echo $work_PATH/orig/${S1_file[$counter]}.SAFE
	    echo
        fi
        

        cp $work_PATH/orig/${S1_file[$counter]}SAFE/manifest.safe $work_PATH/raw/${S1_package:17:8}_manifest.safe
        
        cd $work_PATH/orig/${S1_file[$counter]}SAFE/annotation/
        swath_names=($( ls *.xml ))
        
        cd $work_PATH/raw/      
        
        # [FROM STACK processing -> excluded]
        #
        # In order to correct for Elevation Antenna Pattern Change, cat the manifest and aux files to the xmls
	# delete the first line of the manifest file as it's not a typical xml file.
        # awk 'NR>1 {print $0}' < ${S1_package:17:8}_manifest.safe > tmp_file
	# cat $work_PATH/orig/${S1_file[$counter]}.SAFE/annotation/${swath_names[0]} tmp_file $work_PATH/orig/s1a-aux-cal.xml > ./${swath_names[0]}
	
	swath_counter=1
        for swath_name in ${swath_names[@]}; do
	    swath_names[$swath_counter]=${swath_name::-4}
	    ((swath_counter++))
        done
        
        if [ "$debug" -ge 1 ]; then
	    echo "SWATH NAME 1: ${swath_names[1]}"
	    echo "SWATH NAME 2: ${swath_names[2]}"
	    echo "SWATH NAME 3: ${swath_names[3]}"
        fi
        
        ln -sf $work_PATH/orig/${S1_file[$counter]}SAFE/annotation/*.xml .
        ln -sf $work_PATH/orig/${S1_file[$counter]}SAFE/measurement/*.tiff .
        
        
        # Find adequate orbit files and add symlinks        			
	orbit_list=$( ls $orbits_PATH )

	target_scene=${S1_file[$counter]}
	target_sensor=$( echo ${target_scene:0:3} | tr '[:lower:]' '[:upper:]' )
	target_date=$( date -d "${target_scene:17:8} ${target_scene:26:2}:${target_scene:28:2}:${target_scene:30:2}" '+%s'  )
	
	if [ "$debug" -ge 1 ]; then
	    echo 'Target scene: ' $target_scene
	    echo 'Target sensor: ' $target_sensor
	    echo 'Target date: ' $target_date
	    # echo 'Target date (hr): ' date -d "${target_scene:17:8} ${target_scene:26:2} ${target_scene:28:2} ${target_scene:30:2}" 
	fi


	prev_orbit_startdate=0
	orbit_counter=1
	for orbit in $orbit_list; do
	    
	    if [ ! -z "$orbit" ]; then
		orbit_startdate=$( date -d "${orbit:42:8} ${orbit:51:2}:${orbit:53:2}:${orbit:55:2}" '+%s' )
		orbit_starttime=${orbit:34:6}
		orbit_sensor=${orbit:0:3}	    		
		
		if [ "$debug" -eq 2 ]; then
		    echo "Now working on orbit #: $orbit_counter - $orbit"
		    echo 'Orbit sensor: ' $orbit_sensor
		    echo 'Orbit start date: ' $orbit_startdate
		    echo 'Orbit start time: ' $orbit_starttime
		fi		   
		
		
		if [ "$orbit_sensor" == "$target_sensor" ]; then 
		    if [ $target_date -ge $prev_orbit_startdate ]  &&  [ $target_date -lt $orbit_startdate ]; then
	       		# Looks like we found a matching orbit
	       		# TODO: perform further checks, e.g. end_date overlap
	       		
	       		orbit_match=$prev_orbit
	       		echo "Found matching orbit file: $orbit_match"
	       		ln -sf $orbits_PATH/$orbit_match .	       	    
	       		break
	       	    else
	       		# No match again, get prepared for another round
	       		prev_orbit=$orbit
	       		prev_orbit_startdate=$orbit_startdate 
		    fi
		fi
	    fi
	    
	    ((orbit_counter++))
	done
	
	# if [ $orbit_match = "NaN" ]; then
	#    echo 
	#    echo "WARNING:"
	#    echo "No matching orbit found. Processing not possible!" # TODO: Skip pair
	#    echo "Please check orbit download configuration and orbit download folder."
	#    echo
	# fi

	# Check if single_master mode and  current scene is master scene
	if [ $process_intf_mode = "single_master" ]; then
	    echo
	    echo "Target date: ${target_scene:17:8}"
	    echo "Master scene date: $master_scene_date"
	    echo
	    if [ "$master_scene_date" = "${target_scene:17:8}" ]; then
		# master_scene=$target_scene; master_orbit=$orbit_match
		echo "HOORAY, we have found our master!"
		for swath in ${swaths_to_process[@]}; do
		    echo "${swath_names[$swath]}:$orbit_match" >> data_sm_swath$swath.master
		done
	    else
		for swath in ${swaths_to_process[@]}; do
		    echo "${swath_names[$swath]}:$orbit_match" >> data_sm_swath$swath.tmp
		done
	    fi
	else
	    # TODO: include "both" mode -> sm + pairs
	    for swath in ${swaths_to_process[@]}; do
		echo "${swath_names[$swath]}:$orbit_match" >> data_swath$swath.tmp
            done
	fi
	
	((counter++))

    done

    for swath in ${swaths_to_process[@]}; do
	if [ $process_intf_mode = "single_master" ]; then
	    cat data_sm_swath$swath.master > data_sm_swath$swath.in
	    sort data_sm_swath$swath.tmp  >> data_sm_swath$swath.in  
	    # rm data_sm_swath$swath.tmp data_sm_swath$swath.master
	else
	    sort data_swath$swath.tmp  > data_swath$swath.in  
	    rm data_swath$swath.tmp
	fi
    done

    counter=1
    while [ $counter -lt ${#S1_file[@]} ]; do
	echo "S1 file $counter: ${S1_file[$counter]}" 
	echo "S1 date $counter: ${S1_date[$counter]}"   
	echo 
	((counter++))
    done
fi
