#!/usr/bin/env bash

start=`date +%s`

echo; echo "Starting multiswath processing ..."

s1_pair=$1
config_file=$2
gmtsar_config_file=$3
OSARIS_PATH=$4
direction=$5

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

master_date=${s1_pair:0:8}
slave_date=${s1_pair:10:8}

cd $work_PATH/$s1_pair

echo
echo "- - - - - - - - - - - - - - - - - - - - "
echo "Starting merge_unwrap_geocode ..."
echo 
echo "Current path: $( pwd )"
echo
echo

$OSARIS_PATH/lib/InSAR/merge-unwrap-geocode.sh \
    $work_PATH/merge-files/${s1_pair}.list \
    $config_file \
    $work_PATH/proc-params/boundary-box.xyz

source $OSARIS_PATH/$gmtsar_config_file

echo; echo "Checking results and moving to files to Output directory ..."; echo

if [ ! "$direction" == "reverse" ]; then
    mkdir -p $output_PATH/Amplitudes
    cp -n ./merged/amp1_db_ll.grd $output_PATH/Amplitudes/${master_date}-amplitude-db.grd
    cp -n ./merged/amp2_db_ll.grd $output_PATH/Amplitudes/${slave_date}-amplitude-db.grd
    if [ -f "$output_PATH/Amplitudes/${master_date}-amplitude-db.grd" ] && [ -f "$output_PATH/Amplitudes/${slave_date}-amplitude-db.grd" ]; then status_amp=1; else status_amp=0; fi

    mkdir -p $output_PATH/Interferogram-amplitudes
    cp ./merged/display_amp_ll.grd $output_PATH/Interferogram-amplitudes/${s1_pair}-amplitude.grd
    if [ -f "$output_PATH/Interferogram-amplitudes/${s1_pair}-amplitude.grd" ]; then status_amp=1; else status_amp=0; fi

    mkdir -p $output_PATH/Conn-comps
    cp ./merged/con_comp_ll.grd $output_PATH/Conn-comps/${s1_pair}-conn_comp.grd
    if [ -f "$output_PATH/Conn-comps/${s1_pair}-conn_comp.grd" ]; then status_ccp=1; else status_ccp=0; fi

    mkdir -p $output_PATH/Coherences
    cp ./merged/corr_ll.grd $output_PATH/Coherences/${s1_pair}-coherence.grd
    if [ -f "$output_PATH/Coherences/${s1_pair}-coherence.grd" ]; then status_coh=1; else status_coh=0; fi

    mkdir -p $output_PATH/Interferograms
    cp ./merged/phasefilt_ll.grd $output_PATH/Interferograms/${s1_pair}-interferogram.grd
    if [ -f "$output_PATH/Interferograms/${s1_pair}-interferogram.grd" ]; then status_pha=1; else status_pha=0; fi

    # unwrapping_active=`grep threshold_snaphu $OSARIS_PATH/$gmtsar_config_file | awk '{ print $3 }'`

    if [ $( echo "$threshold_snaphu > 0" | bc -l ) -eq 1 ]; then
	mkdir -p $output_PATH/Interf-unwrpd
	cp ./merged/unwrap_ll.grd $output_PATH/Interf-unwrpd/${s1_pair}-interf_unwrpd.grd
	if [ -f "$output_PATH/Interf-unwrpd/${s1_pair}-interf_unwrpd.grd" ]; then status_unw=1; else status_unw=0; fi
    else
	status_unw=2
    fi
else
    mkdir -p $output_PATH/Interf-unwrpd-rev
    cp ./merged/unwrap_mask_ll.grd $output_PATH/Interf-unwrpd-rev/${s1_pair}-interf_unwrpd.grd
    if [ -f "$output_PATH/Interf-unwrpd-rev/${s1_pair}-interf_unwrpd.grd" ]; then status_unw=1; else status_unw=0; fi
fi





end=`date +%s`
runtime=$((end-start))

echo; echo "Writing report  ..."; echo

echo "${s1_pair:0:8} ${s1_pair:10:8} $SLURM_JOB_ID $runtime $status_amp $status_coh $status_ccp $status_pha $status_unw $status_los" >> $output_PATH/Reports/PP-pairs-stats.tmp

printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n' $(($runtime/86400)) $(($runtime%86400/3600)) $(($runtime%3600/60)) $(($runtime%60))


