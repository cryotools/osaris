#!/usr/bin/env bash

start=`date +%s`

echo; echo "Starting GMTSAR interferometric processing ..."

# SETUP ENVIRONMENT

previous_scene=$1
previous_orbit=$2
current_scene=$3
current_orbit=$4
swath=$5
config_file=$6
gmtsar_config_file=$7
OSARIS_PATH=$8
direction=$9

echo "Reading configuration file $config_file" 
if [ ${config_file:0:2} = "./" ]; then
    config_file=$OSARIS_PATH/${config_file:2:${#config_file}}
fi

source $config_file

work_PATH=$base_PATH/$prefix/Processing
# Path to working directory

output_PATH=$base_PATH/$prefix/Output
# Path to directory where all output will be written

log_PATH=$base_PATH/$prefix/Output/Log
# Path to directory where the log files will be written    

job_ID=${previous_scene:15:8}--${current_scene:15:8}

# proc_mode=$( cat $work_PATH/proc_mode.txt )
# echo "Processing mode: $proc_mode"

mkdir -pv $work_PATH/$job_ID/F$swath/raw 
mkdir -pv $work_PATH/$job_ID/F$swath/topo 
cd $work_PATH/$job_ID/F$swath/topo; ln -sf $topo_PATH/dem.grd .;

cd $work_PATH/raw/$job_ID-F${swath}-aligned/


# ALIGN SCENE PAIRS

echo; echo "- - - - - - - - - - - - - - - - - - - - "

echo "Starting align_cut_tops.csh with options:"
echo "Scene 1: $previous_scene"
echo "Orbit 1: $previous_orbit"
echo "Scene 2: $current_scene"
echo "Orbit 2: $current_orbit"; echo

# TODO: Make bash script
$OSARIS_PATH/lib/GMTSAR-mods/align_cut_tops.csh $previous_scene $previous_orbit $current_scene $current_orbit dem.grd

# if [ "$proc_mode" = "multislice" ]; then
#     echo "Starting align_cut_tops.csh with options:"
#     echo "Scene 1: $previous_scene"
#     echo "Orbit 1: $previous_orbit"
#     echo "Scene 2: $current_scene"
#     echo "Orbit 2: $current_orbit"; echo
#     $OSARIS_PATH/lib/GMTSAR-mods/align_cut_tops.csh $previous_scene $previous_orbit $current_scene $current_orbit dem.grd
# else
#     echo "Starting align_cut_tops.csh with options:"
#     echo "Scene 1: $previous_scene"
#     echo "Orbit 1: $previous_orbit"
#     echo "Scene 2: $current_scene"
#     echo "Orbit 2: $current_orbit"; echo
#     align_tops.csh $previous_scene $previous_orbit $current_scene $current_orbit dem.grd
# fi


# INTERFEROMETRIC PROCESSING

if [ ! -f $work_PATH/raw/$job_ID-F${swath}-aligned/a.grd ] || [ ! -f $work_PATH/raw/$job_ID-F${swath}-aligned/r.grd ]; then
    echo; echo "ERROR: Scene alignment failed. Aborting interferometric processing ..."; echo
else

    cd $work_PATH/$job_ID/F$swath/raw/
    ln -sf $work_PATH/raw/$job_ID-F${swath}-aligned/*F$swath* .
    
    cd $work_PATH/$job_ID/F$swath/

    # Read InSAR configuration from GMTSAR config file 
    source $OSARIS_PATH/$gmtsar_config_file

    if [ -z $filter_wavelength ]; then filter_wavelength=100; fi
    if [ -z $dec_factor ]; then        dec_factor=0; fi


    # if [ ${#swaths_to_process[@]} -gt 1 ]; then
    #echo; echo "Multiple swaths mode (${#swaths_to_process[@]} swaths) ..."
    echo 
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    echo "Starting interferometric processing with options:"
    echo "S1_${previous_scene:15:8}_${previous_scene:24:6}_F$swath"
    echo "S1_${current_scene:15:8}_${current_scene:24:6}_F$swath"
    echo "$gmtsar_config_file" 
    echo "Current directory: $( pwd )"; echo

    master_scene=S1_${previous_scene:15:8}_${previous_scene:24:6}_F$swath
    slave_scene=S1_${current_scene:15:8}_${current_scene:24:6}_F$swath

    # Step 1: Prepare data for interf. proc.
    $OSARIS_PATH/lib/InSAR/prep.sh \
	$master_scene \
	$slave_scene \
	$OSARIS_PATH/$gmtsar_config_file \
	$OSARIS_PATH \
	$work_PATH/proc-params/boundary-box.xyz
    
    # Step 2: Interf. processing
    $OSARIS_PATH/lib/InSAR/intf.sh \
	$master_scene \
	$slave_scene \
	$OSARIS_PATH/$gmtsar_config_file \
	$OSARIS_PATH \
	$work_PATH/proc-params/boundary-box.xyz

    # Step 3: Filter and create result files
    cd intf
    $OSARIS_PATH/lib/InSAR/filter.sh \
	${master_scene}.PRM \
	${slave_scene}.PRM \
	$filter_wavelength \
	$dec_factor
    
    cp -u *gauss* ../../
    cd ..
    
    #$OSARIS_PATH/lib/GMTSAR-mods/p2p_OSARIS_no_unwrap.csh \
    #    $master_scene \
    #    $slave_scene \
    #    $OSARIS_PATH/$gmtsar_config_file \
    #    $OSARIS_PATH \
    #    $work_PATH/proc-params/boundary-box.xyz

    # else
    # echo; echo "Single swath mode ..."; echo 
    # echo "- - - - - - - - - - - - - - - - - - - - "
    # echo "Starting p2p_S1_OSARIS with options:"
    # echo "S1_${previous_scene:15:8}_${previous_scene:24:6}_F$swath"
    # echo "S1_${current_scene:15:8}_${current_scene:24:6}_F$swath"
    # echo "$gmtsar_config_file" 
    # echo "Current directory: $( pwd )"; echo

    # $OSARIS_PATH/lib/GMTSAR-mods/p2p_S1_OSARIS.csh \
    # 	S1_${previous_scene:15:8}_${previous_scene:24:6}_F$swath \
    # 	S1_${current_scene:15:8}_${current_scene:24:6}_F$swath \
    # 	$OSARIS_PATH/$gmtsar_config_file \
    # 	$OSARIS_PATH \
    # 	$work_PATH/proc-params/boundary-box.xyz

    # cd $work_PATH/$job_ID/F$swath/intf/
    # intf_dir=($( ls )) 

    # echo; echo "Checking results and moving to files to Output directory ..."; echo

    # if [ ! "$direction" == "reverse" ]; then
    # 	mkdir -p $output_PATH/Amplitudes
    # 	cp ./$intf_dir/display_amp_ll.grd $output_PATH/Amplitudes/${previous_scene:15:8}--${current_scene:15:8}-amplitude.grd
    # 	if [ -f "$output_PATH/Amplitudes/${previous_scene:15:8}--${current_scene:15:8}-amplitude.grd" ]; then status_amp=1; else status_amp=0; fi

    # 	mkdir -p $output_PATH/Conn-comps
    # 	cp ./$intf_dir/con_comp_ll.grd $output_PATH/Conn-comps/${previous_scene:15:8}--${current_scene:15:8}-conn_comp.grd
    # 	if [ -f "$output_PATH/Conn-comps/${previous_scene:15:8}--${current_scene:15:8}-conn_comp.grd" ]; then status_ccp=1; else status_ccp=0; fi

    # 	mkdir -p $output_PATH/Coherences
    # 	cp ./$intf_dir/corr_ll.grd $output_PATH/Coherences/${previous_scene:15:8}--${current_scene:15:8}-coherence.grd
    # 	if [ -f "$output_PATH/Coherences/${previous_scene:15:8}--${current_scene:15:8}-coherence.grd" ]; then status_coh=1; else status_coh=0; fi

    # 	mkdir -p $output_PATH/Interferograms
    # 	cp ./$intf_dir/phasefilt_mask_ll.grd $output_PATH/Interferograms/${previous_scene:15:8}--${current_scene:15:8}-interferogram.grd
    # 	if [ -f "$output_PATH/Interferograms/${previous_scene:15:8}--${current_scene:15:8}-interferogram.grd" ]; then status_pha=1; else status_pha=0; fi

    # 	unwrapping_active=`grep threshold_snaphu $OSARIS_PATH/$gmtsar_config_file | awk '{ print $3 }'`

    # 	if (( $(echo "$unwrapping_active > 0" | bc -l ) )); then
    # 	    mkdir -p $output_PATH/Interf-unwrpd
    # 	    cp ./$intf_dir/unwrap_mask_ll.grd $output_PATH/Interf-unwrpd/${previous_scene:15:8}--${current_scene:15:8}-interf_unwrpd.grd
    # 	    if [ -f "$output_PATH/Interf-unwrpd/${previous_scene:15:8}--${current_scene:15:8}-interf_unwrpd.grd" ]; then status_unw=1; else status_unw=0; fi
    # 	else
    # 	    status_unw=2
    # 	fi
    # else
    # 	mkdir -p $output_PATH/Interf-unwrpd-rev
    # 	cp ./$intf_dir/unwrap_mask_ll.grd $output_PATH/Interf-unwrpd-rev/${previous_scene:15:8}--${current_scene:15:8}-interf_unwrpd.grd
    # 	if [ -f "$output_PATH/Interf-unwrpd-rev/${previous_scene:15:8}--${current_scene:15:8}-interf_unwrpd.grd" ]; then status_unw=1; else status_unw=0; fi
    # fi

    # fi
fi

end=`date +%s`
runtime=$((end-start))

echo; echo "Writing report  ..."; echo

echo "${previous_scene:15:8} ${current_scene:15:8} $SLURM_JOB_ID $runtime $status_amp $status_coh $status_ccp $status_pha $status_unw $status_los" >> $output_PATH/Reports/PP-pairs-stats.tmp

printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n' $(($runtime/86400)) $(($runtime%86400/3600)) $(($runtime%3600/60)) $(($runtime%60))


