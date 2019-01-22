#!/usr/bin/env bash

start=`date +%s`
echo "SLURM stack processing started"

data_in=$1
config_file=$2
gmtsar_config_file=$3
GSP_directory=$4


if [ ${config_file:0:2} = "./" ]; then
    config_file=$GSP_directory/${config_file:2:${#config_file}}
fi

folder="Stack"

echo "Reading configuration file $config_file" 

source $config_file

work_PATH=$base_PATH/$prefix/Processing
# Path to working directory

output_PATH=$base_PATH/$prefix/Output
# Path to directory where all output will be written

log_PATH=$base_PATH/$prefix/Output/Log
# Path to directory where the log files will be written    





#mkdir -pv $work_PATH/$folder/$job_ID/F$swath/raw 
#mkdir -pv $work_PATH/$folder/$job_ID/F$swath/topo 
#cd $work_PATH/$folder/$job_ID/F$swath/topo; ln -sf $topo_PATH/dem.grd .;

cd $work_PATH/raw

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

# preproc_batch_tops.csh $work_PATH/raw/$data_in $work_PATH/raw/dem.grd 1
preproc_batch_tops_esd.csh $work_PATH/raw/$data_in $work_PATH/raw/dem.grd 1
cp $work_PATH/raw/baseline_table.dat $work_PATH/intf_all/
preproc_batch_tops_esd.csh $work_PATH/raw/$data_in $work_PATH/raw/dem.grd 2

echo "S1A20160124_ALL_F3:S1A20160217_ALL_F3" > intf.in
echo "S1A20160124_ALL_F3:S1A20160312_ALL_F3" >> intf.in
echo "S1A20160124_ALL_F3:S1A20160405_ALL_F3" >> intf.in
echo "S1A20160217_ALL_F3:S1A20160312_ALL_F3" >> intf.in
echo "S1A20160217_ALL_F3:S1A20160312_ALL_F3" >> intf.in

cd ..

#$gmtsar_config_file

#align_tops.csh $previous_scene $previous_orbit $current_scene $current_orbit dem.grd

#cd $work_PATH/$folder/$job_ID/F$swath/raw/
#ln -sf $work_PATH/raw/$job_ID-aligned/*F$swath* .
    
#cd $work_PATH/$folder/$job_ID/F$swath/



echo 
echo "- - - - - - - - - - - - - - - - - - - - "
echo "Starting intfs_tops with options:"
echo "./raw/intf.in"
echo "/home/loibldav/Scripts/gmtsar-sentinel-processing-chain/config/GMTSAR-golubin.config" 

intf_tops.csh $work_PATH/raw/intf.in /home/loibldav/Scripts/gmtsar-sentinel-processing-chain/config/GMTSAR-golubin.config

# p2p_S1A_TOPS.csh
#$GSP_directory/lib/GMTSAR-mods/p2p_S1PPC.csh \
#    S1A${previous_scene:15:8}_${previous_scene:24:6}_F$swath \
#    S1A${current_scene:15:8}_${current_scene:24:6}_F$swath \
#    $GSP_directory/$gmtsar_config_file 


#cd $work_PATH/$folder/$job_ID/F$swath/intf/
#intf_dir=($( ls )) 
        
#output_intf_dir=$output_PATH/$folder/S1A${previous_scene:15:8}_${previous_scene:24:6}_F$swath"---"S1A${current_scene:15:8}_${current_scene:24:6}_F$swath

#mkdir -pv $output_intf_dir

#cp ./$intf_dir/*.grd $output_intf_dir 
#cp ./$intf_dir/*.png $output_intf_dir 
#cp ./$intf_dir/*.kml $output_intf_dir 
#cp ./$intf_dir/*.ps $output_intf_dir 
#cp ./$intf_dir/*.cpt $output_intf_dir 
#cp ./$intf_dir/*.conf $output_intf_dir 



end=`date +%s`

runtime=$((end-start))

printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n' $(($runtime/86400)) $(($runtime%86400/3600)) $(($runtime%3600/60)) $(($runtime%60))



