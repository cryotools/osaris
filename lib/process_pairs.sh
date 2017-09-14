#!/bin/bash

#################################################################
#
# Pair-wise processing of a series of scenes.
# 
# Scenes and orbits must be available in data_swath[nr].in files
# created by prepare_pairs.sh. Processing of coherence and inter-
# ferograms are conducted in individual SLURM jobs for each 
# scene pair.
#
# Usage: process_pairs.sh [config file]
#
################################################################

if [ $# -eq 0 ]; then
    echo
    echo "Usage: process_pairs.sh [config file]"  
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

    GSP_directory=$( pwd )

    work_PATH=$base_PATH/$prefix/Processing
    # Path to working directory

    output_PATH=$base_PATH/$prefix/Output
    # Path to directory where all output will be written

    log_PATH=$base_PATH/$prefix/Output/Log
    # Path to directory where the log files will be written    



    # Process S1 data as defined in data_swath>nr<.in, line by line
    dataline_count=0

    cd $work_PATH/raw/

    for swath in ${swaths_to_process[@]}; do
	while read -r dataline; do
	    cd $work_PATH/raw/
	    
	    echo
	    echo
	    echo "Reading scenes and orbits from file data.in"
	    ((dataline_count++))
	    current_scene=${dataline:0:64}
	    current_orbit=${dataline:65:77}
	    
	    echo "Current scene: $current_scene"
	    echo "Current orbit: $current_orbit"
	    
	    
	    if [ "$dataline_count" -eq 1 ]; then
		echo "First line processed, waiting for more input data"    
	    elif [ -z ${previous_scene+x} ]; then
		echo "The scene was not read correctly from data.in. Please check."
	    elif  [ -z ${previous_orbit+x} ]; then
		echo "The orbit was not read correctly from data.in. Please check."
	    else 	    	
		
		scene_pair_name=${previous_scene:15:8}--${current_scene:15:8}
		echo "Creating directory $scene_pair_name"
		mkdir -pv $scene_pair_name-aligned; cd $scene_pair_name-aligned
		ln -sf $topo_PATH/dem.grd .
		ln -sf $work_PATH/raw/${previous_scene:15:8}_manifest.safe .
		ln -sf $work_PATH/raw/${current_scene:15:8}_manifest.safe .
		#		ln -s $work_PATH/raw/*.LED .
		#		ln -s $work_PATH/raw/*.PRM .
		#		ln -s $work_PATH/raw/*.SLC .

		cp -P $work_PATH/raw/$current_scene.tiff .
		cp -P $work_PATH/raw/$previous_scene.tiff .
		cp -P $work_PATH/raw/$current_scene.xml .
		cp -P $work_PATH/raw/$previous_scene.xml .
		cp -P $work_PATH/raw/$current_orbit .
		cp -P $work_PATH/raw/$previous_orbit .

		if [ "$process_reverse_intfs" -eq 1 ]; then
		    cd $work_PATH/raw/
		    scene_pair_reverse=${current_scene:15:8}--${previous_scene:15:8}
		    echo "Creating reverse directory $scene_pair_name"
		    mkdir -pv $scene_pair_reverse-aligned
		    cp -r --preserve=links $scene_pair_name-aligned/. $scene_pair_reverse-aligned/
		    echo "cp -r --preserve=links $scene_pair_name-aligned/. $scene_pair_reverse-aligned/"
		fi
		
		echo
		echo - - - - - - - - - - - - - - - - 
		echo "Launching SLURM batch jobs"
		echo
		echo "Processing logs will be written to $log_PATH"
		echo "Use tail -f [logfile] to monitor the SLURM tasks"
		echo
		
		slurm_jobname="$slurm_jobname_prefix-pairs"

		sbatch \
		    --ntasks=$slurm_ntasks \
		    --output=$log_PATH/PP-S1A-%j-out \
		    --error=$log_PATH/PP-S1A-%j-out \
		    --workdir=$work_PATH \
		    --job-name=$slurm_jobname \
		    --qos=$slurm_qos \
		    --account=$slurm_account \
		    --partition=$slurm_partition \
		    --mail-type=$slurm_mailtype \
		    $GSP_directory/lib/PP-start-S1A \
		    $previous_scene \
		    $previous_orbit \
		    $current_scene \
		    $current_orbit \
		    $swath \
		    $config_file \
		    $GSP_directory/$gmtsar_config_file \
		    $GSP_directory \
		    "forward"
		
		if [ "$process_reverse_intfs" -eq 1 ]; then

		    slurm_jobname="$slurm_jobname_prefix-rev-pairs"

		    sbatch \
			--ntasks=$slurm_ntasks \
			--output=$log_PATH/PP-S1A-%j-rev-out \
			--error=$log_PATH/PP-S1A-%j-rev-out \
			--workdir=$work_PATH \
			--job-name=$slurm_jobname \
			--qos=$slurm_qos \
			--account=$slurm_account \
			--partition=$slurm_partition \
			--mail-type=$slurm_mailtype \
			$GSP_directory/lib/PP-start-S1A \
			$current_scene \
			$current_orbit \
			$previous_scene \
			$previous_orbit \
			$swath \
			$config_file \
			$GSP_directory/$gmtsar_config_file \
			$GSP_directory \
			"reverse"
		fi

	    fi
	    
	    previous_scene=$current_scene
	    previous_orbit=$current_orbit
	    
	done < "data_swath$swath.in"
    done
fi

