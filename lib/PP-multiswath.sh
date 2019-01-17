#!/usr/bin/env bash

start=`date +%s`

echo; echo "Starting multiswath processing ..."

s1_pair=$1
config_file=$2
gmtsar_config_file=$3
OSARIS_PATH=$4


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

cd $work_PATH/$s1_pair

echo
echo "- - - - - - - - - - - - - - - - - - - - "
echo "Starting merge_unwrap_geocode ..."
echo 
echo "Current path: $( pwd )"
echo
echo

$OSARIS_PATH/lib/GMTSAR-mods/merge_unwrap_geocode.csh \
    $work_PATH/merge-files/${s1_pair} \
    $OSARIS_PATH/$gmtsar_config_file \
    $work_PATH/boundary-box.xyz

# example 300/5900/0/25000 (xmin/xmax/ymin/ymax)
echo; echo "Checking results and moving to files to Output directory ..."; echo


mkdir -p $output_PATH/Amplitudes
cp ./display_amp_ll.grd $output_PATH/Amplitudes/${s1_pair}-amplitude.grd
if [ -f "$output_PATH/Amplitudes/${s1_pair}-amplitude.grd" ]; then status_amp=1; else status_amp=0; fi

mkdir -p $output_PATH/Conn-comps
cp ./con_comp_ll.grd $output_PATH/Conn-comps/${s1_pair}-conn_comp.grd
if [ -f "$output_PATH/Conn-comps/${s1_pair}-conn_comp.grd" ]; then status_ccp=1; else status_ccp=0; fi

mkdir -p $output_PATH/Coherences
cp ./corr_ll.grd $output_PATH/Coherences/${s1_pair}-coherence.grd
if [ -f "$output_PATH/Coherences/${s1_pair}-coherence.grd" ]; then status_coh=1; else status_coh=0; fi

mkdir -p $output_PATH/Interferograms
cp ./phasefilt_mask_ll.grd $output_PATH/Interferograms/${s1_pair}-interferogram.grd
if [ -f "$output_PATH/Interferograms/${s1_pair}-interferogram.grd" ]; then status_pha=1; else status_pha=0; fi

unwrapping_active=`grep threshold_snaphu $OSARIS_PATH/$gmtsar_config_file | awk '{ print $3 }'`

if (( $(echo "$unwrapping_active > 0" | bc -l ) )); then
    mkdir -p $output_PATH/Interf-unwrpd
    cp ./unwrap_mask_ll.grd $output_PATH/Interf-unwrpd/${s1_pair}-interf_unwrpd.grd
    if [ -f "$output_PATH/Interf-unwrpd/${s1_pair}-interf_unwrpd.grd" ]; then status_unw=1; else status_unw=0; fi
else
    status_unw=2
fi





end=`date +%s`
runtime=$((end-start))

echo; echo "Writing report  ..."; echo

echo "${previous_scene:15:8} ${current_scene:15:8} $SLURM_JOB_ID $runtime $status_amp $status_coh $status_ccp $status_pha $status_unw $status_los" >> $output_PATH/Reports/PP-pairs-stats.tmp

printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n' $(($runtime/86400)) $(($runtime%86400/3600)) $(($runtime%3600/60)) $(($runtime%60))


