#!/bin/bash

if [ $# -eq 0 ]; then
    echo
    echo "Usage: osaris.sh [config file]"  
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
    echo "║             OSARIS v. 0.1                ║"
    echo "║   Open Source SAR Investigation System   ║"
    echo "║                                          ║"
    echo "╚══════════════════════════════════════════╝"
    echo 
    echo - - - - - - - - - - - - - - - - - - - - - - - 
    echo    Loading configuration          
    echo - - - - - - - - - - - - - - - - - - - - - - -

    OSARIS_directory=$( pwd )
    echo "OSARIS directory: $OSARIS_directory" 
    echo


    config_file=$1
    if [ ${config_file:0:2} = "./" ]; then
	config_file=$OSARIS_directory/${config_file:2:${#config_file}}
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
    mkdir -pv $work_PATH/topo
    mkdir -pv $output_PATH
    mkdir -pv $log_PATH

    ln -sf $topo_PATH/dem.grd $work_PATH/raw/
    ln -sf $topo_PATH/dem.grd $work_PATH/topo/

    log_filename=GSP-log-$( date +"%Y-%m-%d_%Hh%mm" ).txt
    #err_filename=GSP-errors-$( date +"%Y-%m-%d_%Hh%mm" ).txt
    logfile=$log_PATH/$log_filename

    echo
    echo "Log will be written to $logfile"
    echo "Use tail -f $logfile to monitor overall progress"


    if [ $input_files = "download" ]; then

	echo
	echo - - - - - - - - - - - - - - - -
	echo Downloading Sentinel files
	echo
	
	source $OSARIS_directory/lib/s1_file_download.sh  2>&1 >>$logfile
	
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
	
	source $OSARIS_directory/lib/s1_orbit_download.sh $orbits_PATH 5  2>&1 >>$logfile

	echo 
	echo Orbit update finished
	echo - - - - - - - - - - - - - - - - 
	echo
    fi	        

    echo
    echo - - - - - - - - - - - - - - - -
    echo Preparing SAR data sets ...
    echo

    $OSARIS_directory/lib/prepare_data.sh $config_file 2>&1 >>$logfile

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
	    if [ $process_intf_mode = "pairs" ]; then
		$OSARIS_directory/lib/process_pairs.sh $config_file 2>&1 >>$logfile
		slurm_jobname="$slurm_jobname_prefix-pairs" 

	    elif [ $process_intf_mode = "single_master" ]; then
		echo
		echo "HOORAY, finally in SM mode!"
		echo
		$OSARIS_directory/lib/process_single_master.sh $config_file 2>&1 >>$logfile
		slurm_jobname="$slurm_jobname_prefix-SM" 
	    fi    

	    $OSARIS_directory/lib/check_queue.sh $slurm_jobname 1
	    ;;    
	
	*)
	    echo "$SAR_sensor is not supported, yet. Exiting."
            exit 1
	    
    esac
    

    if [ "$process_reverse_intfs" -eq 1 ]; then
	echo 
	echo - - - - - - - - - - - - - - - - 
	echo Processing unwrapping diffs
	echo
	
	cd $output_PATH/Pairs-forward
	
	folders=($( ls -r ))
	for folder in "${folders[@]}"; do
	    scene_id_1=${folder:0:21}
	    scene_id_2=${folder:24:21}
	    echo "Scene ID 1: $scene_id_1 \n Scene ID 2: $scene_id_2 "
	    $OSARIS_directory/lib/unwrapping-sum.sh \
		$output_PATH/Pairs-forward/$folder/unwrap_mask_ll.grd \
		$output_PATH/Pairs-reverse/$scene_id_2---$scene_id_1/unwrap_mask_ll.grd \
		$output_PATH/Unwrapping-sums \
		$folder-fwd-rev-sum
		2>&1 >>$logfile
	done
    fi

    if [ "$process_coherence_diff" -eq 1 ]; then
	echo 
	echo - - - - - - - - - - - - - - - - 
	echo Processing coherence diffs
	echo

	mkdir -pv $output_PATH/Coherence-diffs

	cd $output_PATH/Pairs-forward

	folders=($( ls -r ))

	for folder in "${folders[@]}"; do
	    echo "Now working on folder: $folder"
	    cd $output_PATH/Pairs-forward
	    if [ ! -z ${folder_1} ]; then
		folder_2=$folder_1
		folder_1=$folder

		coherence_diff_filename=$( echo corr_diff--${folder_2:3:8}-${folder_2:27:8}---${folder_1:3:8}-${folder_1:27:8} )

		$OSARIS_directory/lib/difference.sh \
		    $output_PATH/Pairs-forward/$folder_1/corr_ll.grd \
		    $output_PATH/Pairs-forward/$folder_2/corr_ll.grd \
		    $output_PATH/Coherence-diffs \
		    $coherence_diff_filename 2>&1 >>$logfile
		
		cd $output_PATH/Coherence-diffs
		DX=$( gmt grdinfo $coherence_diff_filename.grd -C | cut -f8 )
		DPI=$( gmt gmtmath -Q $DX INV RINT = )   
		gmt grdimage $coherence_diff_filename.grd \
		    -C$output_PATH/Pairs-forward/$folder/corr.cpt \
		    -Jx1id -P -Y2i -X2i -Q -V > $coherence_diff_filename.ps
		gmt psconvert $coherence_diff_filename.ps \
		    -W+k+t"$coherence_diff_filename" -E$DPI -TG -P -S -V -F$coherence_diff_filename.png
		rm -f $coherence_diff_filename.ps grad.grd ps2raster* psconvert*



	    else
		folder_1=$folder
	    fi
	done
	
	# $OSARIS_directory/lib/coherence_differences.sh $output_PATH/Pairs-forward "corr_ll.grd" 2>&1 >>$logfile
    fi

    if [ "$process_SBAS" -eq 1 ]; then
	echo 
	echo - - - - - - - - - - - - - - - - 
	echo Processing stack + SBAS
	echo
	
	$OSARIS_directory/lib/process_stack.sh $config_file 2>&1 >>$logfile
    fi

    echo
    echo - - - - - - - - - - - - - - - -
    echo Writing reports [todo]

    echo
    echo - - - - - - - - - - - - - - - -
    echo Finished
    echo - - - - - - - - - - - - - - - -
    echo

fi
