#!/bin/bash

if [ $# -eq 0 ]; then
    echo
    echo "Usage: startGSP.sh [config file]"  
    echo
elif [ ! -f $1 ]; then
    echo
    echo "Cannot open $1. Please provide a valid config file."
    echo
else

    echo
    echo
    echo "╔══════════════════════════════════════════╗"
    echo "║                                          ║"
    echo "║ GMTSAR Sentinel Processing Chain v. 0.5  ║"
    echo "║                                          ║"
    echo "╚══════════════════════════════════════════╝"
    echo 
    echo - - - - - - - - - - - - - - - - - - - - - - - 
    echo    Loading configuration          
    echo - - - - - - - - - - - - - - - - - - - - - - -

    GSP_directory=$( pwd )
    echo "GSP directory: $GSP_directory" 
    echo


    config_file=$1
    if [ ${config_file:0:2} = "./" ]; then
	config_file=$GSP_directory/${config_file:2:${#config_file}}
    fi
    echo "Reading configuration file $config_file" 
    source $config_file

  
    echo
    echo "Data will be written to $base_PATH/$prefix/"


    work_PATH=$base_PATH/$prefix/Processing
    # Path to working directory

    output_PATH=$base_PATH/$prefix/Output
    # Path to directory where all output will be written

    log_PATH=$base_PATH/$prefix/Output/Log
    # Path to directory where the log files will be written    

    mkdir -pv $orbits_PATH
    mkdir -pv $work_PATH
    mkdir -pv $work_PATH/raw
    mkdir -pv $output_PATH
    mkdir -pv $log_PATH

    # ln -s $orbits_PATH/*.EOF $work_PATH/raw/ 
    ln -sf $topo_PATH/dem.grd $work_PATH/raw/

    log_filename=GSP-log-$( date +"%Y-%m-%d_%Hh%mm" ).txt
    #err_filename=GSP-errors-$( date +"%Y-%m-%d_%Hh%mm" ).txt
    logfile=$log_PATH/$log_filename
    #errfile=$log_PATH/$err_filename
    echo
    echo "Log will be written to $logfile"
    echo "Use tail -f $logfile to monitor overall progress"
    #echo "Errors will be written to $errfile"
    #echo

    #cmd >$logfile 2>$errfile


    if [ $input_files = "download" ]; then

	echo
	echo - - - - - - - - - - - - - - - -
	echo Downloading Sentinel files
	echo
	
	source $GSP_directory/lib/S1_file_download.sh  2>&1 >>$logfile
	
	echo 
	echo Downloading finished
	echo - - - - - - - - - - - - - - - - 
	echo
    fi

    # Update orbits when requested
    if [ "$update_orbits" -eq 1 ]; then
	echo
	echo - - - - - - - - - - - - - - - -
	echo Updating orbit data ...
	echo
	
	source $GSP_directory/lib/s1_orbit_download.sh $orbits_PATH 5  2>&1 >>$logfile

	echo 
	echo Orbit update finished
	echo - - - - - - - - - - - - - - - - 
	echo
    fi	        

    echo
    echo - - - - - - - - - - - - - - - -
    echo Preparing SAR data sets ...
    echo

    $GSP_directory/lib/prepare_data.sh $config_file 2>&1 >>$logfile
    # source $GSP_directory/lib/prepare_S1_datasets.sh  2>&1 >>$logfile

    echo 
    echo SAR data set preparation finished
    echo - - - - - - - - - - - - - - - - 
    echo

    echo 
    echo - - - - - - - - - - - - - - - -
    echo Starting GMTSAR processing ...
    echo 


    case "$SAR_sensor" in
	Sentinel)
	    $GSP_directory/lib/process_pairs.sh $config_file 2>&1 >>$logfile
            # source $GSP_directory/lib/processSentinel.sh  2>&1 >>$logfile
	    ;;    
	
	*)
            #echo $"Usage: $0 {start|stop|restart|condrestart|status}"
	    echo "$SAR_sensor is not supported, yet. Exiting."
            exit 1
	    
    esac
    slurm_jobname="$slurm_jobname_prefix-pairs" 
    $GSP_directory/lib/check_queue.sh $slurm_jobname 1

    echo 
    echo  Processing 
    echo - - - - - - - - - - - - - - - - 
    echo

    echo
    echo - - - - - - - - - - - - - - - -
    echo Writing reports [todo]

    echo
    echo - - - - - - - - - - - - - - - -
    echo Finished
    echo - - - - - - - - - - - - - - - -
    echo

fi
