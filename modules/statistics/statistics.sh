#!/usr/bin/env bash

######################################################################
#
# OSARIS module to calculate statistics for OSARIS grids
#
# Provide a valid config file named 'statistics.config' in the config
# directory; a template is provided in templates/module_config/
#
# Requires processed GMTSAR result files (e.g., corr_ll.grd) as input.
#
# Output files will be written to $output_PATH/Statistics
#
# David Loibl, 2018
#
#####################################################################

module_name="statistics"

if [ -z $module_config_PATH ]; then
    echo "Parameter module_config_PATH not set in main config file. Setting to default:"
    echo "  $OSARIS_PATH/config"
    module_config_PATH="$OSARIS_PATH/config"
elif [[ "$module_config_PATH" != /* ]] && [[ "$module_config_PATH" != "$OSARIS_PATH"* ]]; then
    module_config_PATH="${OSARIS_PATH}/config/${module_config_PATH}"    
fi

if [ ! -d "$module_config_PATH" ]; then
    echo "ERROR: $module_config_PATH is not a valid directory. Check parameter module_config_PATH in main config file. Exiting ..."
    exit 2
fi

if [ ! -f "${module_config_PATH}/${module_name}.config" ]; then
    echo
    echo "Cannot open ${module_name}.config in ${module_config_PATH}. Please provide a valid config file."
    echo
else
    # Start runtime timer
    stats_start_time=`date +%s`

    # Include the config file
    source ${module_config_PATH}/${module_name}.config


    echo 
    echo - - - - - - - - - - - - - - - - 
    echo Calculating grid statistics
    echo

    mkdir -p $output_PATH/Statistics
    mkdir -p $work_PATH/Statistics

    stats_output_PATH=$output_PATH/Statistics


    if [ "${#stats_input_filenames[@]}" -lt 1 ]; then
	echo "Required variable stats_input_filesnames not set. Aborting statistics calculation ..."
    else
	if [ ! -d $stats_input_PATH ]; then
	    echo; echo "Error: $stats_input_PATH does not exist."
	    echo "Variable stats_input_PATH must be set to a valid directory in statistics.config. Exiting module Statistics."; echo
	else

	    cd $stats_input_PATH
	    
	    folder=${stats_input_PATH%/}
	    folder=${folder##*/}
	    
	    if [ "$stats_subdirs" -eq 0 ]; then

		# List and stats all files of specified filename

		for stats_input_filename in ${stats_input_filenames[@]}; do
		    
		    stats_filename_mod=${stats_input_filename/\*/_}
		    stats_output_file="$stats_output_PATH/${folder}-${stats_input_filename_mod}.csv"
		    
		    echo "Start date,End date,Days,Min,Max,Median,Scale,Mean,Std. dev.,Mode" > $stats_output_file
		    
		    stats_files=($( ls $stats_input_filename ))

		    for stats_file in ${stats_files[@]}; do			

			echo "Adding statistics for $stats_file ..."
		    	
			stats_start_date=${stats_file:0:8}
			stats_end_date=${stats_file:10:8}
			take_diff=$(( ($(date --date="$stats_end_date" +%s) - $(date --date="$stats_start_date" +%s) )/(60*60*24) ))
			if [ -f $stats_input_filename ]; then
			    gmt grdinfo -La $stats_input_filename > $work_PATH/Statistics/${stats_input_filename}.txt
			    stats_min=$( cat $work_PATH/Statistics/${stats_input_filename}.txt | grep z_min | awk '{ print $3 }' )
			    stats_max=$( cat $work_PATH/Statistics/${stats_input_filename}.txt | grep z_min | awk '{ print $5 }' )
			    stats_mean=$( cat $work_PATH/Statistics/${stats_input_filename}.txt | grep mean | awk '{ print $3 }' )
			    stats_stddev=$( cat $work_PATH/Statistics/${stats_input_filename}.txt | grep mean | awk '{ print $5 }' )
			    stats_median=$( cat $work_PATH/Statistics/${stats_input_filename}.txt | grep median | awk '{ print $3 }' )
			    stats_scale=$( cat $work_PATH/Statistics/${stats_input_filename}.txt | grep median | awk '{ print $5 }' )
			    stats_mode=$( cat $work_PATH/Statistics/${stats_input_filename}.txt | grep mode | awk '{ print $3 }' )
			    #{$stats_id},
			    echo "${stats_start_date},${stats_end_date},${take_diff},${stats_min},${stats_max},${stats_median},${stats_scale},${stats_mean},${stats_stddev},${stats_mode}" >> $stats_output_file
			    
			else 
			    echo "$stats_input_filename not found, setting values to NaN ..."
			    echo "${stats_start_date},${stats_end_date},${take_diff},NaN,NaN,NaN,NaN,NaN,NaN,NaN" >> $stats_output_file
			fi

			((stats_id++))
		    done
		done


	    else
		
		# Working in 'scan subdirs' mode ...
		
		cd $stats_input_PATH

		folders=($( ls -d */ ))
		echo; echo "Found ${#folders[@]} subdirectories: ${folders[@]}"; echo
		stats_id=0
		for folder in "${folders[@]}"; do           
		    folder=${folder::-1}
		    cd $folder

		    echo "Now working in directory $folder ..."
		    echo "stats_input_filenames: ${stats_input_filenames[@]}"
		    for stats_input_filename in "${stats_input_filenames[@]}"; do
			
			# Generate a new output csv file for each filename to consider ...
			
			echo "Searching for files matching '$stats_input_filename'"
			stats_filename_mod=${stats_input_filename/\*/_}
			echo "stats_filename_mod: $stats_filename_mod"
			stats_output_file="$stats_output_PATH/${folder}-${stats_filename_mod}.csv"

			echo "Start date,End date,Days,Min,Max,Median,Scale,Mean,Std. dev.,Mode" > $stats_output_file
			    
			stats_files=($( ls $stats_input_filename ))

			for stats_file in ${stats_files[@]}; do

			    # Fill the csv file with stats from all matching grid files in the directory ...

			    echo "Adding statistics for $folder/$stats_file ..."
		    	    
			    stats_start_date=${stats_file:0:8}
			    stats_end_date=${stats_file:10:8}
			    take_diff=$(( ($(date --date="$stats_end_date" +%s) - $(date --date="$stats_start_date" +%s) )/(60*60*24) ))
			    if [ -f $stats_file ]; then
				gmt grdinfo -La $stats_file > $work_PATH/Statistics/${stats_file}-$folder.txt
				stats_min=$( cat $work_PATH/Statistics/${stats_file}-$folder.txt | grep z_min | awk '{ print $3 }' )
				stats_max=$( cat $work_PATH/Statistics/${stats_file}-$folder.txt | grep z_min | awk '{ print $5 }' )
				stats_mean=$( cat $work_PATH/Statistics/${stats_file}-$folder.txt | grep mean | awk '{ print $3 }' )
				stats_stddev=$( cat $work_PATH/Statistics/${stats_file}-$folder.txt | grep mean | awk '{ print $5 }' )
				stats_median=$( cat $work_PATH/Statistics/${stats_file}-$folder.txt | grep median | awk '{ print $3 }' )
				stats_scale=$( cat $work_PATH/Statistics/${stats_file}-$folder.txt | grep median | awk '{ print $5 }' )
				stats_mode=$( cat $work_PATH/Statistics/${stats_file}-$folder.txt | grep mode | awk '{ print $3 }' )
				#{$stats_id},
				echo "${stats_start_date},${stats_end_date},${take_diff},${stats_min},${stats_max},${stats_median},${stats_scale},${stats_mean},${stats_stddev},${stats_mode}" >> $stats_output_file
				
			    else 
				echo "$stats_file not found in folder ${folder}, setting values to NaN ..."
				echo "${stats_start_date},${stats_end_date},${take_diff},NaN,NaN,NaN,NaN,NaN,NaN,NaN" >> $stats_output_file
			    fi

			    ((stats_id++))
			done

			cd ..

		    done		    

		done
	    fi
	
	fi
    fi









    # if [ ! -z $stats_input_filenames ]; then
    # 	for stats_input_filename in "${stats_input_filenames[@]}"; do
	    
    # 	    cd $stats_output_PATH

    # 	    count=0
    # 	    for swath in ${swaths_to_process[@]}; do
		
    # 		stats_output_file="$output_PATH/Statistics/${stats_input_filename::-4}-F${swath}.csv"
    # 		echo "Start date,End date,Days,Min,Max,Median,Scale,Mean,Std. dev.,Mode" > $stats_output_file
		
    # 		stats_id=0
    # 		folders=($( ls -d *-F$swath/ ))
    # 		for folder in "${folders[@]}"; do
    # 		    folder=${folder::-1}		    
		    
    # 		    echo "Adding statistics for $folder/$stats_input_filename ..."
		    	    
    # 		    stats_start_date=${folder:0:8}
    # 		    stats_end_date=${folder:10:8}
    # 		    take_diff=$(( ($(date --date="$stats_end_date" +%s) - $(date --date="$stats_start_date" +%s) )/(60*60*24) ))
    # 		    if [ -f $folder/$stats_input_filename ]; then
    # 			gmt grdinfo -La $folder/$stats_input_filename > $work_PATH/Statistics/${stats_input_filename}-$folder.txt
    # 			stats_min=$( cat $work_PATH/Statistics/${stats_input_filename}-$folder.txt | grep z_min | awk '{ print $3 }' )
    # 			stats_max=$( cat $work_PATH/Statistics/${stats_input_filename}-$folder.txt | grep z_min | awk '{ print $5 }' )
    # 			stats_mean=$( cat $work_PATH/Statistics/${stats_input_filename}-$folder.txt | grep mean | awk '{ print $3 }' )
    # 			stats_stddev=$( cat $work_PATH/Statistics/${stats_input_filename}-$folder.txt | grep mean | awk '{ print $5 }' )
    # 			stats_median=$( cat $work_PATH/Statistics/${stats_input_filename}-$folder.txt | grep median | awk '{ print $3 }' )
    # 			stats_scale=$( cat $work_PATH/Statistics/${stats_input_filename}-$folder.txt | grep median | awk '{ print $5 }' )
    # 			stats_mode=$( cat $work_PATH/Statistics/${stats_input_filename}-$folder.txt | grep mode | awk '{ print $3 }' )
    # 			#{$stats_id},
    # 			echo "${stats_start_date},${stats_end_date},${take_diff},${stats_min},${stats_max},${stats_median},${stats_scale},${stats_mean},${stats_stddev},${stats_mode}" >> $stats_output_file
			
    # 		    else 
    # 			echo "$stats_input_filename not found in folder ${folder}, setting values to NaN ..."
    # 			echo "${stats_start_date},${stats_end_date},${take_diff},NaN,NaN,NaN,NaN,NaN,NaN,NaN" >> $stats_output_file
    # 		    fi

    # 		    ((stats_id++))
    # 		done

    # 	    done

    # 	done
	
    # else
    # 	echo "Require variable stats_input_filesnames not set. Aborting statistics calculation ..."
    # fi




    stats_end_time=`date +%s`
    stats_runtime=$((stats_end_time - stats_start_time))

    printf 'Elapsed wall clock time:\t %02dd %02dh:%02dm:%02ds\n' \
	$(($stats_runtime/86400)) $(($stats_runtime%86400/3600)) $(($stats_runtime%3600/60)) $(($stats_runtime%60)) >> $output_PATH/Reports/statistics.report

fi
