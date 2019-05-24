#!/usr/bin/env bash

#################################################################
#
# Pair-wise processing of a series of scenes.
# 
# Scenes and orbits must be available in data_swath[nr].in files
# created by prepare_data.sh. Processing of coherence and inter-
# ferograms are conducted in individual SLURM jobs for each 
# scene pair.
#
# Usage: process_pairs.sh config_file [processing_mode]
#
# Optional processing mode paramter may be:
# SM - Single master mode
# CMP - Chronologically moving pairs
#
################################################################

if [ $# -eq 0 ]; then
    echo
    echo "Usage: process_pairs.sh config_file [processing_mode]"  
    echo
elif [ ! -f $1 ]; then
    echo
    echo "Cannot open $1. Please provide a valid config file."
    echo
else

    echo
    echo "- - - - - - - - - - - - - - - - - - - -"
    echo " Starting Sentinel data processing ..."
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


    # Process S1 data as defined in data_swath>nr<.in, line by line
    
    if [ $debug -ge 1 ]; then
	if [ "$2" = "SM" ]; then
	    echo; echo "Processing mode: Single Master"
	elif [ "$2" = "CMP" ]; then
	    echo; echo "Processing mode: Chronologically Moving Pairs"
	else
	    echo; echo "No processing mode specified. Processing in 'chronologically moving pairs' mode."
	fi
    fi
    
    for swath in {1..3}; do

	dataline_count=0

	cd $work_PATH/raw/

	if [ "$2" = "SM" ]; then	    
	    data_in_file=data_sm_swath${swath}.in
	    mode="SM"
	elif [ "$2" = "CMP" ]; then
	    data_in_file=data_swath${swath}.in
	    mode="CMP"
	else
	    mode="CMP"
	fi

	echo; echo "Preparing Slurm batch for Swath $swath"

	if [ -f $data_in_file ]; then

	    while read -r dataline; do	    
		cd $work_PATH/raw/	    	    
		((dataline_count++))
		current_scene=${dataline:0:64}
		current_orbit=${dataline:65:77}
		
		echo; echo "Adding data ..."
		echo "Scene: $current_scene"
		echo "Orbit: $current_orbit"
		
		start_processing=1
		
		if [ $mode = "SM" ]; then
		    if [ "$dataline_count" -eq 1 ]; then		
			echo "First line of data_sm.in processed, setting master scene and orbit."
			master_scene=$current_scene
			master_orbit=$current_orbit
			start_processing=0
		    elif [ -z ${master_scene+x} ]; then
			echo "The scene was not read correctly from data.in. Please check."
			start_processing=0
		    elif  [ -z ${master_orbit+x} ]; then
			echo "The orbit was not read correctly from data.in. Please check."
			start_processing=0
		    else
			if [ "${scene_1:15:8}" -eq "${scene_2:15:8}" ]; then		    
			    echo "Scenes ${scene_1:15:8} is equal to ${scene_2:15:8}. Skipping ..."
			    start_processing=0
			fi
		    fi

		else
		    if [ "$dataline_count" -eq 1 ]; then
			echo "First line processed, waiting for more input data"	       
			start_processing=0
		    elif [ -z ${previous_scene+x} ]; then
			echo "The scene was not read correctly from data.in. Please check."
			start_processing=0
		    elif  [ -z ${previous_orbit+x} ]; then
			echo "The orbit was not read correctly from data.in. Please check."
			start_processing=0
		    else
			if [ ! -z $scene_1 ] && [ ! -z $scene_2 ]; then
			    if [ "${scene_1:15:8}" -gt "${scene_2:15:8}" ]; then
				echo "Scenes ${scene_1:15:8} is equal or greater than ${scene_2:15:8}. Skipping ..."
				start_processing=0
			    fi
			fi
		    fi
		fi
		
 		if [ $debug -ge 1 ]; then 
		    echo; echo "Scene 1: ${scene_1:15:8} - Scene 2: ${scene_2:15:8}"
		fi

		


		if [ "$start_processing" -eq "1" ]; then
		    
		    if [ $mode = "SM" ]; then		    
			scene_1=$master_scene
			orbit_1=$master_orbit
			scene_2=$current_scene
			orbit_2=$current_orbit		   		    
		    else		    
			scene_1=$previous_scene
			orbit_1=$previous_orbit
			scene_2=$current_scene
			orbit_2=$current_orbit
		    fi


		    scene_pair_name=${scene_1:15:8}--${scene_2:15:8}
		    echo "$scene_pair_name" >> $work_PATH/pairs-forward.list
		    
		    echo "Creating directory ${scene_pair_name}-aligned"
		    mkdir -p $work_PATH/raw/${scene_pair_name}-F${swath}-aligned; cd $work_PATH/raw/${scene_pair_name}-F${swath}-aligned
		    ln -sf $topo_PATH/dem.grd .
		    ln -sf $work_PATH/raw/${scene_1:15:8}_manifest.safe .
		    ln -sf $work_PATH/raw/${scene_2:15:8}_manifest.safe .
		    ln -sf $work_PATH/raw/$scene_1.tiff .
		    ln -sf $work_PATH/raw/$scene_2.tiff .
		    cp -P $work_PATH/raw/$scene_1.xml .
		    cp -P $work_PATH/raw/$scene_2.xml .
		    cp -P $work_PATH/raw/$orbit_1 .
		    cp -P $work_PATH/raw/$orbit_2 .
		    
		    slurm_jobname="$slurm_jobname_prefix-$mode"
		    
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

		    # Calculate reduced ntasks for basic processing routines
		    echo "Slurm ntasks orig: $slurm_ntasks_pref"
		    slurm_ntasks_pref=$((($slurm_ntasks_pref+1)/2))
		    echo "Slurm ntasks reduced: $slurm_ntasks_pref"
		    
		    sbatch \
			--ntasks=$slurm_ntasks_pref \
			--output=$log_PATH/PP-$mode-%j-out \
			--error=$log_PATH/PP-$mode-%j-out \
			--workdir=$work_PATH \
			--job-name=$slurm_jobname \
			--qos=$slurm_qos \
			--account=$slurm_account \
			--partition=$slurm_partition_pref \
			--mail-type=$slurm_mailtype \
			$OSARIS_PATH/lib/PP-pairs.sh \
			$scene_1 \
			$orbit_1 \
			$scene_2 \
			$orbit_2 \
			$swath \
			$config_file \
			$OSARIS_PATH/$gmtsar_config_file \
			$OSARIS_PATH \
			"forward"


		    if [ ! -z $proc_ifg_revers ] && [ "$proc_ifg_revers" -eq 1 ]; then

			# Process reverse pairs ...

			scene_pair_name=${scene_2:15:8}--${scene_1:15:8}
			echo "$scene_pair_name" >> $work_PATH/pairs-reverse.list
			
			echo "Creating directory $scene_pair_name"
			mkdir -pv $work_PATH/raw/${scene_pair_name}-F${swath}-aligned; cd $work_PATH/raw/${scene_pair_name}-F${swath}-aligned
			ln -sf $topo_PATH/dem.grd .
			ln -sf $work_PATH/raw/${scene_1:15:8}_manifest.safe .
			ln -sf $work_PATH/raw/${scene_2:15:8}_manifest.safe .
			ln -sf $work_PATH/raw/$scene_1.tiff .
			ln -sf $work_PATH/raw/$scene_2.tiff .
			cp -P $work_PATH/raw/$scene_1.xml .
			cp -P $work_PATH/raw/$scene_2.xml .
			cp -P $work_PATH/raw/$orbit_1 .
			cp -P $work_PATH/raw/$orbit_2 .


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
			    --output=$log_PATH/PP-$mode-rev-%j-out \
			    --error=$log_PATH/PP-$mode-rev-%j-out \
			    --workdir=$work_PATH \
			    --job-name=$slurm_jobname \
			    --qos=$slurm_qos \
			    --account=$slurm_account \
			    --partition=$slurm_partition_pref \
			    --mail-type=$slurm_mailtype \
			    $OSARIS_PATH/lib/PP-pairs.sh \
			    $scene_2 \
			    $orbit_2 \
			    $scene_1 \
			    $orbit_1 \
			    $swath \
			    $config_file \
			    $OSARIS_PATH/$gmtsar_config_file \
			    $OSARIS_PATH \
			    "reverse"			
		    fi    
		fi


		previous_scene=$current_scene
		previous_orbit=$current_orbit

	    done < $data_in_file       # "data_swath$swath.in"
	fi
    done
fi

