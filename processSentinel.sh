#!/bin/bash

echo "- - - - - - - - - - - - - - - - - - - -"
echo "Starting Sentinel data processing ..."
echo "- - - - - - - - - - - - - - - - - - - -"

# Before going into detail, remove old stuff and create working dirs
for swath in $swaths; do
    cd $work_PATH
    rm -r F$swath/raw; mkdir F$swath; cd F$swath; mkdir raw; mkdir topo; cd topo; ln -s $topo_PATH/dem.grd .;
done

# Process S1A data as defined in data.in, line by line
dataline_count=0

cd $work_PATH/raw/

while read -r dataline
do
    cd $work_PATH/raw/
    
    echo "Reading scenes and orbits from file data.in"
    ((dataline_count++))
    current_scene=${dataline:0:64}
    current_orbit=${dataline:65:77}
    
    echo "Current scene: $current_scene"
    echo "Current orbit: $current_orbit"
    
    
    if [ "$dataline_count" -eq 1 ]; then
    	echo "First line processed, waiting for more input data"    
    elif [ -z ${previous_scene+x} ]; then
    	echo "The scene was not read correctly from data.in. Please check."
    elif  [ -z ${previous_orbit+x} ]; then
    	echo "The orbit was not read correctly from data.in. Please check."
    else 
    	# TODO: a) process all swaths; b) process swaths as set in $swaths by config.txt    	
    	# echo $theStr | sed s/./A/5        <-- Use this to replace swath-numbers in scene strings ...
    	echo
    	echo "- - - "
    	echo "Starting align_tops.csh with options:"
    	echo "Scene 1: $previous_scene"
    	echo "Orbit 1: $previous_orbit"
    	echo "Scene 2: $current_scene"
    	echo "Orbit 2: $current_orbit"
    	

    	#align_tops.csh $previous_scene $previous_orbit $current_scene $current_orbit dem.grd 
    	
    	# ln -s ../../raw/*F$swath* .
    	cd $work_PATH/F1/raw/
    	ln -s ../../raw/*F1* .
    	
    	cd $work_PATH/F1/
    	
    	echo "- - - "
    	echo "Starting p2p_S1A_TOPS.csh with options:"
    	echo "S1A${previous_scene:15:8}_${previous_scene:24:6}_F1 S1A${current_scene:15:8}_${current_scene:24:6}_F1 $GSP_directory/config.txt"
    	p2p_S1A_TOPS.csh S1A${previous_scene:15:8}_${previous_scene:24:6}_F1 S1A${current_scene:15:8}_${current_scene:24:6}_F1 $GSP_directory/config.txt #>& log &
    fi
    
    previous_scene=$current_scene
    previous_orbit=$current_orbit
        
    #
done < "data.in"

#preproc_batch_tops.csh data.in dem.grd 2

# 1 - start from preprocess
# 2 - start from align SLC images
# 3 - start from make topo_ra 
# 4 - start from make and filter interferograms 
# 5 - start from unwrap phase
# 6 - start from geocode  

# If you are starting from SLC, the script align_tops.csh and p2p_S1A_TOPS.csh should help. For large stacks of data, try preproc_batch_tops.csh and intf_tops.csh


# align_tops.csh s1a-iw1-slc-vv-20150526t014935-20150526t015000-006086-007e23-001 S1A_OPER_AUX_POEORB_OPOD_20150615T155109_V20150525T225944_20150527T005944.EOF.txt s1a-iw1-slc-vv-20150607t014936-20150607t015001-006261-00832e-004 S1A_OPER_AUX_POEORB_OPOD_20150627T155155_V20150606T225944_20150608T005944.EOF.txt dem.grd 
# align_tops.csh s1a-iw2-slc-vv-20150526t014936-20150526t015001-006086-007e23-002 S1A_OPER_AUX_POEORB_OPOD_20150615T155109_V20150525T225944_20150527T005944.EOF.txt s1a-iw2-slc-vv-20150607t014936-20150607t015002-006261-00832e-005 S1A_OPER_AUX_POEORB_OPOD_20150627T155155_V20150606T225944_20150608T005944.EOF.txt dem.grd 
# align_tops.csh s1a-iw3-slc-vv-20150526t014937-20150526t015002-006086-007e23-003 S1A_OPER_AUX_POEORB_OPOD_20150615T155109_V20150525T225944_20150527T005944.EOF.txt s1a-iw3-slc-vv-20150607t014937-20150607t015003-006261-00832e-006 S1A_OPER_AUX_POEORB_OPOD_20150627T155155_V20150606T225944_20150608T005944.EOF.txt dem.grd 
