#!/bin/bash

echo
echo "- - - - - - - - - - - - - - - - - - - -"
echo "Starting data preparation ..."
echo "- - - - - - - - - - - - - - - - - - - -"
echo

cd $input_PATH

counter=1
for S1_package in $( ls -r ); do
    
    # Check if S1_package is valid S1 data directory
    if [[ $S1_package =~ ^S1.* ]]; then
        
	cd $input_PATH
   
	if [ $orig_files = "keep" ]; then
	    echo "Found <keep> flag, skipping file extraction"
	else
            echo Extracting $S1_package ... 
            unzip $S1_package -x *-vh-* -d $work_PATH/orig/
	fi
	
        #echo tar xvf $i -C $work_PATH
        
        #echo ${S1_package:0:${#S1_package}-4}
        S1_file[$counter]=${S1_package:0:${#S1_package}-4}
        #echo ${S1_package:17:8}
        S1_date[$counter]=${S1_package:17:8}
        
        echo $work_PATH/orig/${S1_file[$counter]}.SAFE
        echo

        cp $work_PATH/orig/${S1_file[$counter]}.SAFE/manifest.safe $work_PATH/raw/${S1_package:17:8}_manifest.safe
        
        cd $work_PATH/orig/${S1_file[$counter]}.SAFE/annotation/
        swath_names=($( ls *.xml ))
                                
        
        cd $work_PATH/raw/      
        
        # [FROM STACK processing -> excluded]
        #
        # In order to correct for Elevation Antenna Pattern Change, cat the manifest and aux files to the xmls
	# delete the first line of the manifest file as it's not a typical xml file.
        # awk 'NR>1 {print $0}' < ${S1_package:17:8}_manifest.safe > tmp_file
	# cat $work_PATH/orig/${S1_file[$counter]}.SAFE/annotation/${swath_names[0]} tmp_file $work_PATH/orig/s1a-aux-cal.xml > ./${swath_names[0]}
	
	swath_counter=1
        for swath_name in ${swath_names[@]}; do
            swath_names[$swath_counter]=${swath_name::-4}
            ((swath_counter++))
        done
        
        if [ "$debug" -ge 1 ]; then
            echo "SWATH NAME 0: ${swath_names[1]}"
            echo "SWATH NAME 1: ${swath_names[2]}"
            echo "SWATH NAME 2: ${swath_names[3]}"
        fi
                      
        ln -s $work_PATH/orig/${S1_file[$counter]}.SAFE/annotation/*.xml .
        ln -s $work_PATH/orig/${S1_file[$counter]}.SAFE/measurement/*.tiff .
        

        
        # Find adequate orbit files and add symlinks        			
	orbit_list=$( ls $orbits_PATH )

	target_scene=${S1_file[$counter]}
	target_sensor=$( echo ${target_scene:0:3} | tr '[:lower:]' '[:upper:]' )
	target_date=$( date -d "${target_scene:17:8} ${target_scene:26:2}:${target_scene:28:2}:${target_scene:30:2}" '+%s'  )
	
	if [ "$debug" -ge 1 ]; then
	    echo 'Target scene: ' $target_scene
	    echo 'Target sensor: ' $target_sensor
	    echo 'Target date: ' $target_date
	    echo 'Target date (hr): ' date -d "${target_scene:17:8} ${target_scene:26:2}:${target_scene:28:2}:${target_scene:30:2}" 
	fi    

	prev_orbit_startdate=0
	orbit_counter=1
	for orbit in $orbit_list; do
	    
	    orbit_startdate=$( date -d "${orbit:42:8} ${orbit:51:2}:${orbit:53:2}:${orbit:55:2}" '+%s' )
	    orbit_starttime=${orbit:34:6}
	    orbit_sensor=${orbit:0:3}
	    
	    if [ "$debug" -eq 2 ]; then
		echo "Now working on orbit #: $orbit_counter - $orbit"
		echo 'Orbit sensor: ' $orbit_sensor
		echo 'Orbit start date: ' $orbit_startdate
		echo 'Orbit start time: ' $orbit_starttime
	    fi		   
	    
	    
	    if [ "$orbit_sensor" == "$target_sensor" ]; then 
		if [ $target_date -ge $prev_orbit_startdate ]  &&  [ $target_date -lt $orbit_startdate ]; then
	       	    # Looks like we found a matching orbit
	       	    # TODO: perform further checks, e.g. end_date overlap
	       	    
	       	    orbit_match=$prev_orbit
	       	    echo "Found matching orbit file: $orbit_match"
	       	    ln -s $orbits_PATH/$orbit_match .	       	    
	       	    break
	       	else
	       	    # No match again, get prepared for another round
	       	    prev_orbit=$orbit
	       	    prev_orbit_startdate=$orbit_startdate 
		fi
	    fi
		        
	    ((orbit_counter++))
	done
	
	# if [ $orbit_match = "NaN" ]; then
	#    echo 
	#    echo "WARNING:"
	#    echo "No matching orbit found. Processing not possible!" # TODO: Skip pair
	#    echo "Please check orbit download configuration and orbit download folder."
	#    echo
	# fi

	for swath in ${swaths_to_process[@]}; do
            echo "${swath_names[$swath]}:$orbit_match" >> data_swath$swath.tmp
        done       
		
	((counter++))
    fi
done

for swath in ${swaths_to_process[@]}; do
    sort data_swath$swath.tmp  > data_swath$swath.in  
    rm data_swath$swath.tmp
done

counter=1
while [ $counter -lt ${#S1_file[@]} ]; do
    echo "S1 file $counter: ${S1_file[$counter]}" 
    echo "S1 date $counter: ${S1_date[$counter]}"   
    echo 
    ((counter++))
done
