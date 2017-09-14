#!/bin/bash

echo
echo "- - - - - - - - - - - - - - - - - - - -"
echo "Starting Sentinel data processing ..."
echo "- - - - - - - - - - - - - - - - - - - -"
echo

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
	    ln -s $topo_PATH/dem.grd .
	    ln -s $work_PATH/raw/${previous_scene:15:8}_manifest.safe .
	    ln -s $work_PATH/raw/${current_scene:15:8}_manifest.safe .
	    #		ln -s $work_PATH/raw/*.LED .
	    #		ln -s $work_PATH/raw/*.PRM .
	    #		ln -s $work_PATH/raw/*.SLC .

	    cp -P $work_PATH/raw/$current_scene.tiff .
	    cp -P $work_PATH/raw/$previous_scene.tiff .
	    cp -P $work_PATH/raw/$current_scene.xml .
	    cp -P $work_PATH/raw/$previous_scene.xml .
	    cp -P $work_PATH/raw/$current_orbit .
	    cp -P $work_PATH/raw/$previous_orbit .

	    
          
	    echo
	    echo - - - - - - - - - - - - - - - - 
	    echo "Launching SLURM batch jobs"
	    echo
	    echo "Processing logs will be written to $log_PATH"
	    echo "Use tail -f [logfile] to monitor the SLURM tasks"
	    echo


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
		$work_PATH \
		$topo_PATH \
		$GSP_directory/$gmtsar_config_file \
		$output_PATH                
	    
	    # --ntasks-per-node=2 --cpus-per-task=5


	fi
	
	previous_scene=$current_scene
	previous_orbit=$current_orbit
	
    done < "data_swath$swath.in"
done


