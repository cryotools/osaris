#!/usr/bin/env bash

start=`date +%s`

echo; echo "Starting GMTSAR interferometric processing ..."

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

mkdir -pv $work_PATH/$job_ID/F$swath/raw 
mkdir -pv $work_PATH/$job_ID/F$swath/topo 
cd $work_PATH/$job_ID/F$swath/topo; ln -sf $topo_PATH/dem.grd .;

cd $work_PATH/raw/$job_ID-aligned/

echo
echo "- - - - - - - - - - - - - - - - - - - - "
echo "Starting align_tops.csh with options:"
echo "Scene 1: $previous_scene"
echo "Orbit 1: $previous_orbit"
echo "Scene 2: $current_scene"
echo "Orbit 2: $current_orbit"    	
echo 
echo "Current path: $( pwd )"
echo "align_tops.csh $previous_scene $previous_orbit $current_scene $current_orbit dem.grd"
echo
echo

if [ "$cut_to_aoi" -eq 1 ] && [ ! ${#swaths_to_process[@]} -gt 1 ]; then
    $OSARIS_PATH/lib/GMTSAR-mods/align_cut_tops.csh $previous_scene $previous_orbit $current_scene $current_orbit dem.grd
else
    align_tops.csh $previous_scene $previous_orbit $current_scene $current_orbit dem.grd
fi

cd $work_PATH/$job_ID/F$swath/raw/
ln -sf $work_PATH/raw/$job_ID-aligned/*F$swath* .
    
cd $work_PATH/$job_ID/F$swath/



#########
# TODO:
# Rewrite to 
# (a) include merging of swaths & cutting to AOI, and 
# (b)fit the new directory structure.
#########

if [ ${#swaths_to_process[@]} -gt 1 ]; then
    echo; echo "Multiple swaths mode (${#swaths_to_process[@]} swaths) ..."
    echo 
    echo "- - - - - - - - - - - - - - - - - - - - "
    echo "Starting p2p_S1A_TOPS with options:"
    echo "S1A${previous_scene:15:8}_${previous_scene:24:6}_F$swath"
    echo "S1A${current_scene:15:8}_${current_scene:24:6}_F$swath"
    echo "$gmtsar_config_file" 
    echo "Current directory: $( pwd )"
    echo

    # p2p_S1A_TOPS.csh
    $OSARIS_PATH/lib/GMTSAR-mods/p2p_S1_OSARIS.csh \
	S1_${previous_scene:15:8}_${previous_scene:24:6}_F$swath \
	S1_${current_scene:15:8}_${current_scene:24:6}_F$swath \
	$OSARIS_PATH/$gmtsar_config_file \
	$OSARIS_PATH 


    # Conduct merging of swaths
    # Step 1: check if swaths have the same count in azimuth
    # Step 2: merge swaths
    # Step 3: Cut to AOI extend
else
    echo; echo "Single swath mode ..."
    # Proceed to phase unwrapping ....
    echo 
    echo "- - - - - - - - - - - - - - - - - - - - "
    echo "Starting p2p_S1A_TOPS with options:"
    echo "S1A${previous_scene:15:8}_${previous_scene:24:6}_F$swath"
    echo "S1A${current_scene:15:8}_${current_scene:24:6}_F$swath"
    echo "$gmtsar_config_file" 
    echo "Current directory: $( pwd )"
    echo

    # p2p_S1A_TOPS.csh
    $OSARIS_PATH/lib/GMTSAR-mods/p2p_S1_OSARIS.csh \
	S1_${previous_scene:15:8}_${previous_scene:24:6}_F$swath \
	S1_${current_scene:15:8}_${current_scene:24:6}_F$swath \
	$OSARIS_PATH/$gmtsar_config_file \
	$OSARIS_PATH 

fi

cd $work_PATH/$job_ID/F$swath/intf/
intf_dir=($( ls )) 

echo; echo "Checking results and moving to files to Output directory ..."; echo

if [ ! "$direction" == "reverse" ]; then
    mkdir -p $output_PATH/Amplitudes
    cp ./$intf_dir/display_amp_ll.grd $output_PATH/Amplitudes/${previous_scene:15:8}--${current_scene:15:8}-amplitude.grd
    if [ -f "$output_PATH/Amplitudes/${previous_scene:15:8}--${current_scene:15:8}-amplitude.grd" ]; then status_amp=1; else status_amp=0; fi

    mkdir -p $output_PATH/Conn-comps
    cp ./$intf_dir/con_comp_ll.grd $output_PATH/Conn-comps/${previous_scene:15:8}--${current_scene:15:8}-conn_comp.grd
    if [ -f "$output_PATH/Conn-comps/${previous_scene:15:8}--${current_scene:15:8}-conn_comp.grd" ]; then status_ccp=1; else status_ccp=0; fi

    mkdir -p $output_PATH/Coherences
    cp ./$intf_dir/corr_ll.grd $output_PATH/Coherences/${previous_scene:15:8}--${current_scene:15:8}-coherence.grd
    if [ -f "$output_PATH/Coherences/${previous_scene:15:8}--${current_scene:15:8}-coherence.grd" ]; then status_coh=1; else status_coh=0; fi

    mkdir -p $output_PATH/Interferograms
    cp ./$intf_dir/phasefilt_mask_ll.grd $output_PATH/Interferograms/${previous_scene:15:8}--${current_scene:15:8}-interferogram.grd
    if [ -f "$output_PATH/Interferograms/${previous_scene:15:8}--${current_scene:15:8}-interferogram.grd" ]; then status_pha=1; else status_pha=0; fi

    unwrapping_active=`grep threshold_snaphu $OSARIS_PATH/$gmtsar_config_file | awk '{ print $3 }'`

    if (( $(echo "$unwrapping_active > 0" | bc -l ) )); then
	mkdir -p $output_PATH/Interf-unwrpd
	cp ./$intf_dir/unwrap_mask_ll.grd $output_PATH/Interf-unwrpd/${previous_scene:15:8}--${current_scene:15:8}-interf_unwrpd.grd
	if [ -f "$output_PATH/Interf-unwrpd/${previous_scene:15:8}--${current_scene:15:8}-interf_unwrpd.grd" ]; then status_unw=1; else status_unw=0; fi
    else
	status_unw=2
    fi
else
    mkdir -p $output_PATH/Interf-unwrpd-rev
    cp ./$intf_dir/unwrap_mask_ll.grd $output_PATH/Interf-unwrpd-rev/${previous_scene:15:8}--${current_scene:15:8}-interf_unwrpd.grd
    if [ -f "$output_PATH/Interf-unwrpd-rev/${previous_scene:15:8}--${current_scene:15:8}-interf_unwrpd.grd" ]; then status_unw=1; else status_unw=0; fi
fi

end=`date +%s`
runtime=$((end-start))

echo; echo "Writing report  ..."; echo

echo "${previous_scene:15:8} ${current_scene:15:8} $SLURM_JOB_ID $runtime $status_amp $status_coh $status_ccp $status_pha $status_unw $status_los" >> $output_PATH/Reports/PP-pairs-stats.tmp

printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n' $(($runtime/86400)) $(($runtime%86400/3600)) $(($runtime%3600/60)) $(($runtime%60))


