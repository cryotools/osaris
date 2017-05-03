#!/bin/bash

echo "- - - - - - - - - - - - - - - - - - - -"
echo "Starting Sentinel data processing ..."
echo "- - - - - - - - - - - - - - - - - - - -"

# Before going into detail, remove old stuff and create working dirs
for swath in ${swaths_to_process[@]}; do
    cd $work_PATH
    rm -rf F$swath/raw; mkdir -pv F$swath/raw topo; cd topo; ln -s $topo_PATH/dem.grd .;
done

# Process S1A data as defined in data_swath>nr<.in, line by line
dataline_count=0

cd $work_PATH/raw/

for swath in ${swaths_to_process[@]}; do
	while read -r dataline
	do
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
	    	
	    	echo
	    	echo "- - - "
	    	echo "Starting align_tops.csh with options:"
	    	echo "Scene 1: $previous_scene"
	    	echo "Orbit 1: $previous_orbit"
	    	echo "Scene 2: $current_scene"
	    	echo "Orbit 2: $current_orbit"    	
		
	    	align_tops.csh $previous_scene $previous_orbit $current_scene $current_orbit dem.grd 

	    	# Process data (a) in SLURM-based parallel processing envrionment or (b) one by one.
	    	# Set the parallel_preocessing variable in config.txt
	    	if [ "$parallel_processing" -eq 1 ]; then
	    	    # Going parallel > add jobs to SLURM queue 
                
	    	    sbatch $GSP_directory/PP-start-S1A $previous_scene $previous_orbit $current_scene $current_orbit $swath $work_PATH $GSP_directory $gmtsar_config_file $output_PATH
                # sbatch $GSP_directory/PP-start-S1A S1A${previous_scene:15:8}_${previous_scene:24:6}_F$swath S1A${current_scene:15:8}_${current_scene:24:6}_F$swath $GSP_directory $gmtsar_config_file $dataline_count
	    	else
	    	    # No SLURM activated > compute data one by one ...	    	    	    	   
	    		    	    
	    	    cd $work_PATH/F$swath/raw/
	    	    ln -s ../../raw/*F$swath* .
	    	
	    	    cd $work_PATH/F$swath/
	    	
	    	    echo
	    	    echo "- - - "
	    	    echo "Starting p2p_S1A_TOPS.csh with options:"
	    	    echo "S1A${previous_scene:15:8}_${previous_scene:24:6}_F$swath S1A${current_scene:15:8}_${current_scene:24:6}_F$swath $GSP_directory/$gmtsar_config_file"
	    	    p2p_S1A_TOPS.csh S1A${previous_scene:15:8}_${previous_scene:24:6}_F$swath S1A${current_scene:15:8}_${current_scene:24:6}_F$swath $GSP_directory/$gmtsar_config_file 2>&1 | tee $logfile 
	    	    
	    	    cd $work_PATH/F$swath/intf/
	    	    intf_dir=($( ls )) 
	    	    
	    	    mkdir -pv $output_PATH/Interferograms/S1A${previous_scene:15:8}_${previous_scene:24:6}_F$swath"---"S1A${current_scene:15:8}_${current_scene:24:6}_F$swath
	    	    cp ./$intf_dir/* $output_PATH/Interferograms/S1A${previous_scene:15:8}_${previous_scene:24:6}_F$swath"---"S1A${current_scene:15:8}_${current_scene:24:6}_F$swath
	    	fi
	    fi
	    
	    previous_scene=$current_scene
	    previous_orbit=$current_orbit
	    	    	    	 
	done < "data_swath$swath.in"
done


