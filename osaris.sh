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
    echo " ╔══════════════════════════════════════════╗"
    echo " ║                                          ║"
    echo " ║             OSARIS v. 0.2.1              ║"
    echo " ║   Open Source SAR Investigation System   ║"
    echo " ║                                          ║"
    echo " ╚══════════════════════════════════════════╝"
    echo 
    echo - - - - - - - - - - - - - - - - - - - - - - - 
    echo    Loading configuration          
    echo - - - - - - - - - - - - - - - - - - - - - - -

    OSARIS_PATH=$( pwd )
    echo "OSARIS directory: $OSARIS_PATH" 
    echo


    config_file=$1
    if [ ${config_file:0:2} = "./" ]; then
	config_file=$OSARIS_PATH/${config_file:2:${#config_file}}
    fi
    echo "Reading configuration file $config_file" 
    source $config_file

  
    echo
    echo "Data will be written to $base_PATH/$prefix/"


    work_PATH=$base_PATH/$prefix/Processing
    # Path to working directory

    output_PATH=$base_PATH/$prefix/Output
    # Path to directory where all output will be written

    log_PATH=$base_PATH/$prefix/Log
    # Path to directory where the log files will be written    

    mkdir -p $orbits_PATH
    mkdir -p $work_PATH
    mkdir -p $work_PATH/raw
    mkdir -p $work_PATH/topo
    mkdir -p $output_PATH
    mkdir -p $log_PATH

    ln -sf $topo_PATH/dem.grd $work_PATH/raw/
    ln -sf $topo_PATH/dem.grd $work_PATH/topo/

    log_filename=$prefix-$( date +"%Y-%m-%d_%Hh%mm" ).log
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

	input_PATH=$base_PATH/$prefix/Input/S1-orig

	source $OSARIS_PATH/lib/s1-file-download.sh  2>&1 >>$logfile
	
	echo 
	echo Downloading finished
	echo - - - - - - - - - - - - - - - - 
	echo
    else
	if [ ! -d $input_files ]; then
	    echo "Please set 'input_files' param in config file either to <download> or to a valid directory path"
	else
	    input_PATH=$input_files       
	    # S1 files already exist -> read from directory specified in .config file	
	fi
    fi



    # Update orbits when requested
    if [ "$update_orbits" -eq 1 ]; then
	echo
	echo - - - - - - - - - - - - - - - -
	echo Updating orbit data ...
	echo
	
	source $OSARIS_PATH/lib/s1-orbit-download.sh $orbits_PATH 5  2>&1 >>$logfile

	echo 
	echo Orbit update finished
	echo - - - - - - - - - - - - - - - - 
	echo
    fi	        




    echo
    echo - - - - - - - - - - - - - - - -
    echo Preparing SAR data sets ...
    echo

    if [ $orig_files = "keep" ]; then
	echo "Skipping file extraction ('orig_files' param set to <keep> in config file)."
	PS_extract=0
    elif [ $orig_files = "extract" ]; then
	echo "Startinng file extraction."
	PS_extract=1
    else
	echo "No vaild value for 'orig_files' param found. Please check the config file. Trying to extract files..."
	PS_extract=1
    fi
    
    if [ $PS_extract -eq 1 ]; then	
	
	mkdir -p $work_PATH/orig		
	echo
	echo - - - - - - - - - - - - - - - - 

	cd $input_PATH

	for S1_archive in $( ls -r ); do	   	    
	    # Check if S1_package is valid S1 data directory
	    if [[ $S1_archive =~ ^S1.* ]]; then
		
		# TODO: Add option to extract without slurm for systems without unzip installed.
		
		echo "Sending extract job for Sentinel file $S1_archive to SLURM queue."
		# echo "$OSARIS_PATH/lib/PP-extract.sh"
		# echo "$input_PATH/$S1_archive"
		# echo "$work_PATH/orig"
		
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
		    $OSARIS_PATH/lib/PP-extract.sh $input_PATH $S1_archive $work_PATH/orig
	    fi
	done

	$OSARIS_PATH/lib/check-queue.sh $slurm_jobname 2 0

	cd $OSARIS_PATH
    fi

    $OSARIS_PATH/lib/prepare-data.sh $config_file 2>&1 >>$logfile

    echo 
    echo SAR data set preparation finished
    echo - - - - - - - - - - - - - - - - 
    echo




    echo 
    echo - - - - - - - - - - - - - - - -
    echo Starting interferometric processing ...
    echo 
    
    case "$SAR_sensor" in
	Sentinel)	    

	    if [ $process_intf_mode = "pairs" ]; then
		echo
		echo "Initializing processing in 'chronologically moving pairs' mode."
		echo

		$OSARIS_PATH/lib/process-pairs.sh $config_file CMP 2>&1 >>$logfile
		slurm_jobname="$slurm_jobname_prefix-CMP" 
		$OSARIS_PATH/lib/check-queue.sh $slurm_jobname 1

	    elif [ $process_intf_mode = "single_master" ]; then
		echo
		echo "Initializing processing in 'single master' mode."
		echo

		$OSARIS_PATH/lib/process-pairs.sh $config_file SM 2>&1 >>$logfile		
		slurm_jobname="$slurm_jobname_prefix-SM" 
		$OSARIS_PATH/lib/check-queue.sh $slurm_jobname 1

	    elif [ $process_intf_mode = "both" ]; then
		echo
		echo "Initializing processing in both 'single master' and 'chronologically moving pairs' modes."
		echo

		$OSARIS_PATH/lib/process-pairs.sh $config_file SM 2>&1 >>$logfile
		slurm_jobname="$slurm_jobname_prefix-SM" 
		$OSARIS_PATH/lib/check-queue.sh $slurm_jobname 1

		$OSARIS_PATH/lib/process-pairs.sh $config_file CPR 2>&1 >>$logfile
		slurm_jobname="$slurm_jobname_prefix-CPR" 
		$OSARIS_PATH/lib/check-queue.sh $slurm_jobname 1

	    fi  	   	    	    
	   
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
	    $OSARIS_PATH/lib/unwrapping-sum.sh \
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

	mkdir -p $output_PATH/Coherence-diffs

	cd $output_PATH/Pairs-forward

	folders=($( ls -r ))

	for folder in "${folders[@]}"; do
	    echo "Now working on folder: $folder"
	    cd $output_PATH/Pairs-forward
	    if [ ! -z ${folder_1} ]; then
		folder_2=$folder_1
		folder_1=$folder

		coherence_diff_filename=$( echo corr_diff--${folder_2:3:8}-${folder_2:27:8}---${folder_1:3:8}-${folder_1:27:8} )

		$OSARIS_PATH/lib/difference.sh \
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
	
	# $OSARIS_PATH/lib/coherence_differences.sh $output_PATH/Pairs-forward "corr_ll.grd" 2>&1 >>$logfile
    fi

    if [ "$process_SBAS" -eq 1 ]; then
	echo 
	echo - - - - - - - - - - - - - - - - 
	echo Processing stack + SBAS
	echo
	
	$OSARIS_PATH/lib/process-stack.sh $config_file 2>&1 >>$logfile
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
