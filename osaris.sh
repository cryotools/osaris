#!/usr/bin/env bash

if [ $# -eq 0 ]; then
    echo
    echo "Usage: osaris.sh [config file]"  
    echo
elif [ ! -f $1 ]; then
    echo
    echo "Cannot open $1. Please provide a valid config file."
    echo
else
    OSARIS_start_time=$( date +%s )
    run_identifier=$( date +"%F_%H-%M_%Z" )
    echo
    echo
    echo " ╔══════════════════════════════════════════╗"
    echo " ║                                          ║"
    echo " ║             OSARIS v. 0.7.2              ║"
    echo " ║   Open Source SAR Investigation System   ║"
    echo " ║                                          ║"
    echo " ╚══════════════════════════════════════════╝"
    echo 
    echo - - - - - - - - - - - - - - - - - - - - - - - 
    echo    Loading configuration          
    echo - - - - - - - - - - - - - - - - - - - - - - -


    function include_modules {
	module_array=("${@}")
	module_count=${#module_array[@]}
	if [ $module_count -gt 0 ]; then
	    for module in "${module_array[@]}"; do
		# Check if module exists		
		if [ -d "$OSARIS_PATH/modules/$module" ]; then
		    if [ -f "$OSARIS_PATH/modules/$module/$module.sh" ]; then
			# Everthing looks fine, include the module
			echo; echo "Starting module $module"; echo

			# Start module time measurement
			printf '\n\n$module\n' >> $output_PATH/Reports/$report_filename
			module_timer_start=$( date +%s )
			
			source $OSARIS_PATH/modules/$module/$module.sh &>>$log_PATH/$module.log

			# Finish time measurement and add to report
			module_timer_end=$( date +%s )	    
			module_walltime=$((module_timer_end-module_timer_start))	    	    
			printf 'Wallclock time:\t %02dd %02dh:%02dm:%02ds\n' $(($module_walltime/86400)) $(($module_walltime%86400/3600)) $(($module_walltime%3600/60)) $(($module_walltime%60)) >> $output_PATH/Reports/$report_filename

			echo "Log file will be written to $log_PATH/$module.log"
		    else
			echo; echo "WARNING: File $module.sh not found in module directory. Skipping."; echo
		    fi
		else
		    echo; echo "WARNING: Module $module not found. Skipping."; echo
		fi	
	    done
	# else
	#    echo "No modules to implement, Skipping ..."
	fi    
    }

    
    # INITIAL SETUP

    export OSARIS_PATH=$( pwd )
    echo "OSARIS directory: $OSARIS_PATH" 
    echo


    config_file=$1
    if [ ${config_file:0:2} = "./" ]; then
	config_file=$OSARIS_PATH/${config_file:2:${#config_file}}
    fi
    echo "Reading configuration file $config_file" 
    source $config_file

    echo; echo "Data will be written to $base_PATH/$prefix/"

    # Check login credentials
    if [ ! -f $credentials_file ]; then
	echo; echo "WARNING: Login credentials file not found at ${credentials_file}" 
	echo "Downloading will probably not work."
	credentials_found=0
    else
	echo; echo "Loading login credentials from ${credentials_file}"
	source $credentials_file
	credentials_found=1
    fi
    
    # Check module configuration directory
    skip_modules=0
    if [ ! -z $module_config_PATH ]; then	
	if [ ! -d "${OSARIS_PATH}/config/$module_config_PATH" ]; then
	    echo; echo "WARNING: ${OSARIS_PATH}/config/${module_config_PATH} is not a vaild directory." 
	    echo "Please check the value of module_config_PATH in the main configuration file."
	    echo "Modules integration was deactivated."
	    skip_modules=1
	else
	    echo; echo "Found module configuration directory ${module_config_PATH}"	    
	fi
    fi        

    export work_PATH=$base_PATH/$prefix/Processing
    # Path to working directory

    export output_PATH=$base_PATH/$prefix/Output
    # Path to directory where all output will be written

    export log_PATH=$base_PATH/$prefix/Log
    # Path to directory where the log files will be written    

    mkdir -p $orbits_PATH
    mkdir -p $work_PATH/raw
    mkdir -p $work_PATH/topo
    mkdir -p $output_PATH/Reports
    mkdir -p $log_PATH

    if [ ! -f $topo_PATH/dem.grd ]; then
	echo; echo
	echo "CRITICAL CONFIGURATION ERROR:"
	echo "Topo file not found at $topo_PATH/dem.grd"
	echo "Review your configuration and restart the processing."
	echo "Exiting ..."; echo
	exit
    else
	ln -sf $topo_PATH/dem.grd $work_PATH/raw/
	ln -sf $topo_PATH/dem.grd $work_PATH/topo/        
    fi


    # PREPARE LOGFILES

    log_filename=$prefix-$run_identifier.log
    report_filename=$prefix-$run_identifier.report
    
    logfile=$log_PATH/$log_filename
    
    printf "OSARIS log file for ${prefix}\n\nStart time: $run_identifier\n" > $logfile
    echo
    echo "Log will be written to $logfile"
    echo "Use tail -f $logfile to monitor overall progress"

    
    #### STEP 1: DOWNLOADS

    if [ $input_files = "download" ]; then
	if [ "$credentials_found" -eq 1 ]; then
	    echo; echo - - - - - - - - - - - - - - - -; echo "Downloading Sentinel-1 files"; echo
	    input_PATH=$base_PATH/$prefix/Input/
	    mkdir -p $input_PATH

	    source $OSARIS_PATH/lib/s1-file-download.sh  2>&1 >>$log_PATH/downloads.log
	    
	    echo; echo Downloading finished; echo - - - - - - - - - - - - - - - -; echo
	else
	    echo "No login credentials found. Skipping file download."
	fi
    else
	if [ ! -d $input_files ]; then
	    echo "CRITICAL CONFIGURAION ERROR:"
	    echo "Parameter 'input_files' in config file must either be set to <download> or to a valid directory. Exiting."
	    exit 1
	else
	    input_PATH=$input_files       
	    # S1 files already exist -> read from directory specified in .config file	
	fi
    fi

    # Create input file csv
    cd $input_PATH
    input_files=($( ls *.zip ))

    # Make sure no old files are around
    rm -f $work_PATH/input_files.csv $output_PATH/input_files.csv 

    for input_file in ${input_files[@]}; do
	input_file_elements=${input_file//_/ }
	input_file_startdatetime=$( echo $input_file_elements | awk '{ print $5 }' )
	input_file_startdatetime=${input_file_startdatetime/T/ }
	input_file_start_date=$( echo $input_file_startdatetime | awk '{ print $1 }' )
	input_file_start_time=$( echo $input_file_startdatetime | awk '{ print $2 }' )
	input_file_enddatetime=$( echo $input_file_elements | awk '{ print $6 }' )
	input_file_enddatetime=${input_file_enddatetime/T/ }
	input_file_end_date=$( echo $input_file_enddatetime | awk '{ print $1 }' )
	input_file_end_time=$( echo $input_file_enddatetime | awk '{ print $2 }' )
 
	input_file_sensor=$( echo $input_file_elements | awk '{ print $1 }' )
	input_file_mode=$( echo $input_file_elements | awk '{ print $2 }' )
	input_file_format=$( echo $input_file_elements | awk '{ print $3 }' )
	input_file_type=$( echo $input_file_elements | awk '{ print $4 }' )

	echo "$input_file_start_date $input_file_start_time $input_file_end_date $input_file_end_time $input_file_sensor $input_file_mode $input_file_type $input_type_format" >> $work_PATH/input_files.csv
    done    
    sort $work_PATH/input_files.csv > $output_PATH/input_files.csv


    # Update orbits if requested
    if [ "$update_orbits" -eq 1 ]; then

	# Start orbit update time measurement
	printf '\n\nOrbit download\n' >> $output_PATH/Reports/$report_filename
	orbit_timer_start=$( date +%s )	

	echo; echo - - - - - - - - - - - - - - - -; echo "Updating orbit data ..."; echo
	if [ "$orbit_provider" = "ESA" ]; then
	    source $OSARIS_PATH/lib/s1-orbit-download.sh $orbits_PATH 5 &>>$log_PATH/downloads.log
	elif [ "$orbit_provider" = "ASF" ]; then
            if [ -z "$ASF_username" ] || [ -z "$ASF_password" ]; then
		echo; echo "ERROR: Missing ASF login credentials."
		echo "Please review your login credentials file."		
	    else
		echo "Found ASF login credentials. Starting orbit download ..."
		wget --http-user=$ASF_username --http-password=$ASF_password -r -l 1 -nc -nd --no-check-certificate -nH --accept EOF -P $orbits_PATH https://s1qc.asf.alaska.edu/aux_poeorb/ &>>$log_PATH/downloads.log
	    fi	    
	fi

	echo; echo "Orbit update finished"; echo - - - - - - - - - - - - - - - - ; echo
	
	# Finish time measurement and add to report
	orbit_timer_end=$( date +%s )	    
	orbit_walltime=$((orbit_timer_end-orbit_timer_start))	    	    
	printf 'Wallclock time:\t %02dd %02dh:%02dm:%02ds\n' $(($orbit_walltime/86400)) $(($orbit_walltime%86400/3600)) $(($orbit_walltime%3600/60)) $(($orbit_walltime%60)) >> $output_PATH/Reports/$report_filename

    fi	        


    #### HOOK 1: Post download modules
    if [ ! "$skip_modules" -eq 1 ]; then
	include_modules "${post_download_mods[@]}"
    fi



    #### STEP 2: PREPARE DATA
    if [ "$skip_pre_processing" -eq 1 ]; then
	echo; echo - - - - - - - - - - - - - - - -; echo "Skipping pre-processing (skip_pre_processing set to 1 in config file) ..."; echo 
    else

	echo;  echo - - - - - - - - - - - - - - - -; echo "Preparing SAR data sets ..."; echo

	if [ $orig_files = "keep" ]; then
	    echo "Skipping file extraction ('orig_files' param set to <keep> in config file)."
	    PS_extract=0
	elif [ $orig_files = "extract" ]; then
	    echo "Starting file extraction."
	    PS_extract=1
	else
	    echo "No vaild value for 'orig_files' param found. Please check the config file. Trying to extract files..."
	    PS_extract=1
	fi
	
	if [ $PS_extract -eq 1 ]; then	

	    # Strart extract time measurement
	    printf '\n\nS1 File extraction' >> $output_PATH/Reports/$report_filename
	    extract_timer_start=$( date +%s )

	    mkdir -p $work_PATH/orig		
	    echo
	    echo - - - - - - - - - - - - - - - - 
	    
	    if [ -z $polarization ]; then polarization="vv"; fi
	    
	    cd $input_PATH

	    for S1_archive in $( ls -r ); do	   	    
		# Check if S1_package is valid S1 data directory
		if [[ $S1_archive =~ ^S1.* ]]; then
		    
		    # TODO: Add option to extract without slurm for systems without unzip installed.
		    
		    echo "Sending extract job for Sentinel file $S1_archive to SLURM queue."
		    
		    slurm_jobname="$slurm_jobname_prefix-EXT"		

		    sbatch \
			--output=$log_PATH/extract-%j.log \
			--error=$log_PATH/extract-%j.log \
			--workdir=$input_PATH \
			--job-name=$slurm_jobname \
			--qos=$slurm_extract_qos \
			--account=$slurm_account \
			--partition=$slurm_extract_partition \
			--mail-type=$slurm_mailtype \
			$OSARIS_PATH/lib/PP-extract.sh $input_PATH $S1_archive $work_PATH/orig $output_PATH $polarization
		fi
	    done

	    $OSARIS_PATH/lib/check-queue.sh $slurm_jobname 2 0

	    # End extract time measurement and add to report
	    extract_timer_end=$( date +%s )	    
	    extract_walltime=$((extract_timer_end-extract_timer_start))	    	    
	    printf 'Wallclock time:\t %02dd %02dh:%02dm:%02ds\n' $(($extract_walltime/86400)) $(($extract_walltime%86400/3600)) $(($extract_walltime%3600/60)) $(($extract_walltime%60)) >> $output_PATH/Reports/$report_filename

	    cd $OSARIS_PATH
	fi

	$OSARIS_PATH/lib/prepare-data.sh $config_file 2>&1 >>$logfile

	echo; echo "SAR data set preparation finished"; echo - - - - - - - - - - - - - - - - ; echo
    fi


    #### HOOK 2: Post extract modules
    if [ ! "$skip_modules" -eq 1 ]; then
	include_modules "${post_extract_mods[@]}"
    fi


    #### STEP 3: INTERFEROMETRIC PROCESSING

    if [ "$skip_intf_processing" -eq 1 ]; then
	echo; echo - - - - - - - - - - - - - - - -; echo "Skipping interferometric processing (skip_intf_processing set to 1 in config file) ..."; echo 
    else
	echo; echo - - - - - - - - - - - - - - - -; echo "Starting interferometric processing ..."; echo 
	
	# Start interferometric processing time measurement
	printf '\n\nInterferometric Processing\n' >> $output_PATH/Reports/$report_filename
	interf_timer_start=$( date +%s )

	
	case "$SAR_sensor" in
	    Sentinel)	    
		
		if [ $process_intf_mode = "pairs" ]; then
		    echo; echo "Initializing processing in 'chronologically moving pairs' mode."; echo
		    cd $OSARIS_PATH
		    $OSARIS_PATH/lib/process-pairs.sh $config_file CMP 2>&1 >>$logfile
		    slurm_jobname="$slurm_jobname_prefix-CMP" 
		    $OSARIS_PATH/lib/check-queue.sh $slurm_jobname 1
		    
		    # If more than one swath are to be considered, start the merging and unwrapping procedure ...
		    if [ ${#swaths_to_process[@]} -gt 1 ]; then
			$OSARIS_PATH/lib/process-multi-swath.sh $config_file 2>&1 >>$logfile
			slurm_jobname="$slurm_jobname_prefix-MSP" 
			$OSARIS_PATH/lib/check-queue.sh $slurm_jobname 1
		    fi

		elif [ $process_intf_mode = "single_master" ]; then
		    echo; echo "Initializing processing in 'single master' mode."; echo
		    cd $OSARIS_PATH
		    $OSARIS_PATH/lib/process-pairs.sh $config_file SM 2>&1 >>$logfile		
		    slurm_jobname="$slurm_jobname_prefix-SM" 
		    $OSARIS_PATH/lib/check-queue.sh $slurm_jobname 1
		    
		    # If more than one swath are to be considered, start the merging and unwrapping procedure ...
		    if [ ${#swaths_to_process[@]} -gt 1 ]; then
			$OSARIS_PATH/lib/process-multi-swath.sh $config_file 2>&1 >>$logfile
			slurm_jobname="$slurm_jobname_prefix-MSP" 
			$OSARIS_PATH/lib/check-queue.sh $slurm_jobname 1
		    fi

		# elif [ $process_intf_mode = "both" ]; then
		#     echo; echo "Initializing processing in both 'single master' and 'chronologically moving pairs' modes.";	echo
		#     cd $OSARIS_PATH
		#     $OSARIS_PATH/lib/process-pairs.sh $config_file SM 2>&1 >>$logfile
		#     slurm_jobname="$slurm_jobname_prefix-SM" 
		#     $OSARIS_PATH/lib/check-queue.sh $slurm_jobname 1
		#     cd $OSARIS_PATH
		#     $OSARIS_PATH/lib/process-pairs.sh $config_file CMP 2>&1 >>$logfile
		#     slurm_jobname="$slurm_jobname_prefix-CMP" 
		#     $OSARIS_PATH/lib/check-queue.sh $slurm_jobname 1

		fi  	   	    	    
		
		;;    
	    
	    *)
		echo "$SAR_sensor is not supported, yet. Exiting."
		exit 1
		
	esac

	# Finish time measurement and add to report
	interf_timer_end=$( date +%s )	    
	interf_walltime=$((interf_timer_end-interf_timer_start))	    	    
	printf 'Wallclock time:\t %02dd %02dh:%02dm:%02ds\n' $(($interf_walltime/86400)) $(($interf_walltime%86400/3600)) $(($interf_walltime%3600/60)) $(($interf_walltime%60)) >> $output_PATH/Reports/$report_filename


    fi

    #### HOOK 3: Post processing modules

    if [ ! "$skip_modules" -eq 1 ]; then	
	include_modules "${post_processing_mods[@]}"
    fi



    #### STEP 4: POSTPROCESSING

    # Move files from $work_PATH/Pairs-forward to directories in $output_PATH
    # as specified by the var $output_directory_map in the config file

    # echo; echo - - - - - - - - - - - - - - - -; echo "Moving files to output directories ...";	echo

    # if [ -z "$output_directory_map" ]; then
    # 	echo "Variable output_directory_map not set in config file. Using default mapping ..."
    # 	output_directory_map=( "display_amp_ll.grd:Amplitudes" "corr_ll.grd:Coherences" "phasefilt_mask_ll.grd:Interferograms-raw" "unwrap_mask_ll.grd:Interferograms-unwrapped" )
    # fi

    # # Create array of output directories
    

    # for file_dir_pair in ${output_directory_map[@]}; do
	
    # 	# Split by ':'
    # 	mkdir -p __

    # 	for _directory_ in ${__direcotry_list__[@]}; do

    # 	    # Move stuff to output directory

    # 	done

    # done


    # TODO: Make module
    if [ "$process_reverse_intfs" -eq 1 ]; then
	
	# Start unwrapping sum time measurement
	printf '\n\nFwd-Rev-Unwrapping sum calculation' >> $output_PATH/Reports/$report_filename
	unwrsum_timer_start=$( date +%s )


	echo; echo - - - - - - - - - - - - - - - -; echo "Processing differences between forward and reverse pairs of unwrapped interferograms ...";	echo
	
	cd $output_PATH/Interf-unwrpd
	
	intf_files=($( ls *.grd ))
	for intf_file in "${intf_files[@]}"; do
	    scene_id_1=${intf_file:0:8}
	    scene_id_2=${intf_file:10:8}
	    echo "Scene ID 1: $scene_id_1 \n Scene ID 2: $scene_id_2 "
	    $OSARIS_PATH/lib/unwrapping-sum.sh \
		$output_PATH/Interf-unwrpd/${scene_id_1}--${scene_id_2}-interf_unwrpd.grd \
		$output_PATH/Interf-unwrpd-rev/${scene_id_2}--${scene_id_1}-interf_unwrpd.grd \
		$output_PATH/Unwrapping-sums \
		${scene_id_1}--${scene_id_2}-fwd-rev-sum &>>$logfile
	done

	# Finish time measurement and add to report
	unwrsum_timer_end=$( date +%s )	    
	unwrsum_walltime=$((unwrsum_timer_end-unwrsum_timer_start))	    	    
	printf 'Wallclock time:\t %02dd %02dh:%02dm:%02ds\n' $(($unwrsum_walltime/86400)) $(($unwrsum_walltime%86400/3600)) $(($unwrsum_walltime%3600/60)) $(($unwrsum_walltime%60)) >> $output_PATH/Reports/$report_filename


    fi

    # TODO: Make module
    if [ ! -z $process_SBAS ] && [ "$process_SBAS" -eq 1 ]; then
	echo 
	echo - - - - - - - - - - - - - - - - 
	echo Processing stack + SBAS
	echo
	
	$OSARIS_PATH/lib/process-stack.sh $config_file &>>$logfile
    fi

    if [ $clean_up -gt 0 ]; then
	echo
	echo - - - - - - - - - - - - - - - -
	echo Cleaning up a bit ...
	if [ $clean_up -eq 1 ]; then
	    echo "Deleting files used during processing, keeping extracted S1 scenes ..."
	    rm -rf $work_PATH/Pairs-forward $work_PATH/raw $work_PATH/topo $work_PATH/single_master $work_PATH/orig_cut $work_PATH/UCM
	elif [ $clean_up -eq 2 ]; then
	    echo "Deleting processing folder ..."
	    rm -rf $work_PATH
	else
	    echo "Invalid value provided for 'clean_up' param, skipping. Please check your config file."
	fi
    fi

    #### HOOK 4: Post post-postprocessing modules
    
    if [ ! "$skip_modules" -eq 1 ]; then
	include_modules "${post_postprocessing_mods[@]}"
    fi

    #### STEP 5: CALCULATE STATS AND WRITE REPORTS

    OSARIS_end_time=`date +%s`
    OSARIS_runtime=$((OSARIS_end_time-OSARIS_start_time))
      

    echo; echo - - - - - - - - - - - - - - - -
    echo Processing finished; echo
    echo Writing reports ... ; echo

    source $OSARIS_PATH/lib/reporting.sh &>>$logfile

    total_runtime=$((OSARIS_runtime + PP_total_runtime + PP_extract_total_runtime))
    # TODO: Add module runtimes

    if [ $debug -eq 1 ]; then
	echo; echo
	echo "Debugging messages for time measurements:"
	echo "- Time stamp start: $OSARIS_start_time"
	echo "- Time stamp end:   $OSARIS_end_time"
	echo "- OSARIS runtime:   $OSARIS_runtime"
	echo "- PP job runtime:   $PP_total_runtime"
	echo "- Extract runtime:  $PP_extract_total_runtime"
	echo "- Total runtime:    $total_runtime"
	echo
    fi

    echo; echo "Elapsed total processing time (estimate):"
    printf '%02dd %02dh:%02dm:%02ds\n' $(($total_runtime/86400)) $(($total_runtime%86400/3600)) $(($total_runtime%3600/60)) $(($total_runtime%60))
    echo
    echo "Elapsed wall clock time:"
    printf '%02dd %02dh:%02dm:%02ds\n' $((OSARIS_runtime/86400)) $((OSARIS_runtime%86400/3600)) $((OSARIS_runtime%3600/60)) $((OSARIS_runtime%60))
    echo

   
    echo
    echo - - - - - - - - - - - - - - - -
    echo Finished
    echo - - - - - - - - - - - - - - - -
    echo

fi
