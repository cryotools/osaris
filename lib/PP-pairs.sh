#!/bin/bash

start=`date +%s`

echo "Starting GMTSAR interferometric processing ..."

previous_scene=$1
previous_orbit=$2
current_scene=$3
current_orbit=$4
swath=$5
config_file=$6
gmtsar_config_file=$7
OSARIS_directory=$8
direction=$9

folder="Pairs-$direction"


echo "Reading configuration file $config_file" 
if [ ${config_file:0:2} = "./" ]; then
    config_file=$OSARIS_directory/${config_file:2:${#config_file}}
fi

source $config_file


work_PATH=$base_PATH/$prefix/Processing
# Path to working directory

output_PATH=$base_PATH/$prefix/Output
# Path to directory where all output will be written

log_PATH=$base_PATH/$prefix/Output/Log
# Path to directory where the log files will be written    



job_ID=${previous_scene:15:8}--${current_scene:15:8}

mkdir -pv $work_PATH/$folder/$job_ID/F$swath/raw 
mkdir -pv $work_PATH/$folder/$job_ID/F$swath/topo 
cd $work_PATH/$folder/$job_ID/F$swath/topo; ln -sf $topo_PATH/dem.grd .;

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

if [ "$cut_to_aoi" -eq 1 ]; then
    $OSARIS_PATH/lib/GMTSAR-mods/align_cut_tops.csh $previous_scene $previous_orbit $current_scene $current_orbit dem.grd
else
    align_tops.csh $previous_scene $previous_orbit $current_scene $current_orbit dem.grd
fi

cd $work_PATH/$folder/$job_ID/F$swath/raw/
ln -sf $work_PATH/raw/$job_ID-aligned/*F$swath* .
    
cd $work_PATH/$folder/$job_ID/F$swath/

echo 
echo "- - - - - - - - - - - - - - - - - - - - "
echo "Starting p2p_S1A_TOPS with options:"
echo "S1A${previous_scene:15:8}_${previous_scene:24:6}_F$swath"
echo "S1A${current_scene:15:8}_${current_scene:24:6}_F$swath"
echo "$gmtsar_config_file" 

# p2p_S1A_TOPS.csh
$OSARIS_directory/lib/GMTSAR-mods/p2p_S1PPC.csh \
    S1A${previous_scene:15:8}_${previous_scene:24:6}_F$swath \
    S1A${current_scene:15:8}_${current_scene:24:6}_F$swath \
    $OSARIS_directory/$gmtsar_config_file 


cd $work_PATH/$folder/$job_ID/F$swath/intf/
intf_dir=($( ls )) 
        
output_intf_dir=$output_PATH/$folder/F$swath/S1${previous_scene:15:8}_${previous_scene:24:6}_F$swath"---"S1${current_scene:15:8}_${current_scene:24:6}_F$swath

mkdir -pv $output_intf_dir

cp ./$intf_dir/*.grd $output_intf_dir 
cp ./$intf_dir/*.png $output_intf_dir 
cp ./$intf_dir/*.kml $output_intf_dir 
cp ./$intf_dir/*.ps $output_intf_dir 
cp ./$intf_dir/*.cpt $output_intf_dir 
cp ./$intf_dir/*.conf $output_intf_dir 


echo; echo "Checking results and writing report ..."; echo

cd $output_intf_dir
unwrapping_active=`grep threshold_snaphu $OSARIS_directory/$gmtsar_config_file | awk '{ print $3 }'`

if [ -f "display_amp_ll.grd" ]; then status_amp=1; else status_amp=0; fi
if [ -f "corr_ll.grd" ]; then status_coh=1; else status_coh=0; fi
if [ -f "phase_mask_ll.grd" ]; then status_pha=1; else status_pha=0; fi

if (( $(echo "$unwrapping_active > 0" | bc -l ) )); then
    if [ -f "unwrap_mask_ll.grd" ]; then status_unw=1; else status_unw=0; fi
    if [ -f "los_ll.grd" ]; then status_los=1; else status_los=0; fi
else
    status_unw=2
    status_los=2
fi

end=`date +%s`
runtime=$((end-start))

echo "${previous_scene:15:8} ${current_scene:15:8} $SLURM_JOB_ID $runtime $status_amp $status_coh $status_pha $status_unw $status_los" >> $output_PATH/Reports/PP-pairs-stats.tmp

printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n' $(($runtime/86400)) $(($runtime%86400/3600)) $(($runtime%3600/60)) $(($runtime%60))


