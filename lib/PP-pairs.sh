#!/bin/bash

start=`date +%s`
echo "Processing started"

previous_scene=$1
previous_orbit=$2
current_scene=$3
current_orbit=$4
swath=$5
config_file=$6
gmtsar_config_file=$7
OSARIS_directory=$8
direction=$9

if [ ${config_file:0:2} = "./" ]; then
    config_file=$OSARIS_directory/${config_file:2:${#config_file}}
fi

folder="Pairs-$direction"

echo "Reading configuration file $config_file" 

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

align_tops.csh $previous_scene $previous_orbit $current_scene $current_orbit dem.grd

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



end=`date +%s`

runtime=$((end-start))

printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n' $(($runtime/86400)) $(($runtime%86400/3600)) $(($runtime%3600/60)) $(($runtime%60))


