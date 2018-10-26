#!/usr/bin/env bash

#################################################################
#
# Preparation of SAR data sets.
# Find matching orbits and write data.in files for each swath.
# 
# Usage: prepare_data.sh config_file
#
################################################################



function find_matching_orbit {

    # Find adequate orbit files and add symlinks        			

    S1_file=$1    
    orbit_list=$2

    target_scene=${S1_file}
    target_sensor=$( echo ${target_scene:0:3} | tr '[:lower:]' '[:upper:]' )
    target_date=$( date -d "${target_scene:17:8} ${target_scene:26:2}:${target_scene:28:2}:${target_scene:30:2}" '+%s'  )
    
    prev_orbit_startdate=0
    orbit_counter=1

    orbit_match="none"

    for orbit in ${orbit_list[@]}; do
	
	if [ ! -z "$orbit" ]; then
	    orbit_startdate=$( date -d "${orbit:42:8} ${orbit:51:2}:${orbit:53:2}:${orbit:55:2}" '+%s' )
	    orbit_starttime=${orbit:34:6}
	    orbit_sensor=${orbit:0:3}	    			        
	    
	    if [ "$orbit_sensor" == "$target_sensor" ]; then 
		if [ $target_date -ge $prev_orbit_startdate ]  &&  [ $target_date -lt $orbit_startdate ]; then
	       	    # Looks like we found a matching orbit
	       	    # TODO: perform further checks, e.g. end_date overlap
	       	    
	       	    orbit_match=$prev_orbit
	       	    #echo "Found matching orbit file: $orbit_match"
	       	    ln -sf $orbits_PATH/$orbit_match $work_PATH/raw/
		    echo $orbit_match
	       	    break
	       	else
	       	    # No match again, get prepared for another round
	       	    prev_orbit=$orbit
	       	    prev_orbit_startdate=$orbit_startdate 
		fi
	    fi
	fi
	
	((orbit_counter++))
    done
}

function write_data_in_tmp {
    target_scene=$1
    orbit_match=$2
    name_stem=$3
    swath=$4

    # Check if single_master mode and  current scene is master scene
    if [ $process_intf_mode = "single_master" ]; then
	echo
	echo "Target date: ${target_scene:17:8}"
	echo "Master scene date: $master_scene_date"
	echo
	if [ "$master_scene_date" = "${target_scene:17:8}" ]; then
	    # master_scene=$target_scene; master_orbit=$orbit_match
	    echo "HOORAY, we have found our master!"
	    echo "${name_stem}:$orbit_match" >> data_sm_swath$swath.master	    
	else	 
	    echo "${name_stem}:$orbit_match" >> data_sm_swath$swath.tmp		
	fi
    else
	# TODO: include "both" mode -> sm + pairs	
	echo "${name_stem}:$orbit_match" >> data_swath$swath.tmp
	
    fi
}


if [ $# -eq 0 ]; then
    echo
    echo "Usage: prepare_data.sh config_file"  
    echo
elif [ ! -f $1 ]; then
    echo
    echo "Cannot open $1. Please provide a valid config file."
    echo
else

    echo
    echo "- - - - - - - - - - - - - - - - - - - -"
    echo " Starting data preparation ..."
    echo "- - - - - - - - - - - - - - - - - - - -"
    echo

    config_file=$1
    echo "config file: $config_file"
    source $config_file
    
    OSARIS_PATH=$( pwd )

    work_PATH=$base_PATH/$prefix/Processing
    # Path to working directory

    log_PATH=$base_PATH/$prefix/Log
    # Path to directory where the log files will be written    
    
    orbit_list=$( ls $orbits_PATH )

    
    if [ "$cut_to_aoi" -eq 1 ] && [ "${#swaths_to_process[@]}" -eq 1 ]; then
       	mkdir -p $work_PATH/orig_cut/temp/
	rm -f $work_PATH/orig_cut/temp/filelist.txt

	# Find scenes originating from the same pass in orig directory ...
	cd $work_PATH/orig/
	
	scene_list=(*.SAFE)	
	i=0; for scene in ${scene_list[@]}; do scene_dates[$i]=${scene:17:8}; ((i++)); done	
	readarray -t scene_dates_sorted < <(printf '%s\0' "${scene_dates[@]}" | sort -z | xargs -0n1)
	
	i=0
	for scene_date in ${scene_dates_sorted[@]}; do
	    if [ "$i" -gt 0 ]; then
		if [ "${scene_dates_sorted[$i]}" -eq $prev_scene_date ]; then
		    echo "Found two matching scenes for $prev_scene_date." 
		    find . -maxdepth 1 -name "*$prev_scene_date*.SAFE"
		    find . -maxdepth 1 -name "*$prev_scene_date*.SAFE" >> $work_PATH/orig_cut/temp/filelist.txt		    
		else
		    echo "No matching scene for $prev_scene_date found. "
		fi
		prev_scene_date=${scene_dates_sorted[$i]}
	    else
		
		prev_scene_date=${scene_dates_sorted[$i]}
	    fi
	    ((i++))
	done
	
	i=1
	while read -r current_file; do
	    current_file=${current_file:2}
	    if [ "$debug" -ge 1 ]; then 
		echo; echo; echo "Iteration $i"
		echo "Current file: $current_file"
		echo "Current date: ${current_file:17:8}"
		echo "Previous file: $prev_file"
		echo "Previous date: ${prev_file:17:8}"
	    fi
	    	    

	    # In each second iteration, cut the pair to AoI extent ...
	    # if [ "$i" -gt 1 ] && [ "$( expr $i % 2)" -eq 0 ]; then		    
	    if [ "$i" -gt 1 ]; then
		if [ "${current_file:17:8}" -eq "${prev_file:17:8}" ]; then
		    
		    # Find matching orbit
		    # orbit_match=$( find_matching_orbit $current_file $orbit_list )

		    # if [ "$debug" -ge 1 ]; then 
		    #     echo; echo "Found two scenes for ${current_file:17:8}"
		    #     echo "Matching orbit: $orbit_match"
		    # fi

		    S1_file=$current_file
		    target_scene=${S1_file}
		    target_sensor=$( echo ${target_scene:0:3} | tr '[:lower:]' '[:upper:]' )	    
		    if [ -z $target_scene ]; then
			echo "Skipping scene $target_scene ..."
		    else
			echo "$( date -d "${target_scene:17:8} ${target_scene:26:2}:${target_scene:28:2}:${target_scene:30:2}" '+%s'  )" 
			target_date=$( date -d "${target_scene:17:8} ${target_scene:26:2}:${target_scene:28:2}:${target_scene:30:2}" '+%s'  ) 
		    fi
		    
		    orbit_counter=1
		    orbit_match="none"

		    for orbit in $orbit_list; do
			if [ ! -z "$orbit" ] && [ "${orbit:42:8}" != " " ]; then		
			    date_string="${orbit:42:8} ${orbit:51:2}:${orbit:53:2}:${orbit:55:2}"
			    orbit_startdate=$( date -d "$date_string" '+%s' )
			    orbit_starttime=${orbit:34:6}
			    orbit_sensor=${orbit:0:3}	    		
			    
			    if [ "$debug" -eq 2 ]; then
				echo "Now working on orbit #: $orbit_counter - $orbit"
				echo 'Orbit sensor: ' $orbit_sensor
				echo 'Orbit start date: ' $orbit_startdate
				echo 'Orbit start time: ' $orbit_starttime
			    fi		   			
			    
			    if [ "$orbit_sensor" == "$target_sensor" ]; then 
				if [ -z ${prev_orbit_startdate} ] || [ -z ${orbit_startdate} ]; then
				    echo "Orbit date not configured properly ($prev_orbit_startdate - $orbit_startdate)... Skipping."
				    prev_orbit=$orbit
				    prev_orbit_startdate=$orbit_startdate 
				else
				    if [ "$target_date" -ge "$prev_orbit_startdate" ]  &&  [ "$target_date" -lt "$orbit_startdate" ]; then
	       				# Looks like we found a matching orbit
	       				# TODO: perform further checks, e.g. end_date overlap
	       				
	       				orbit_match=$prev_orbit
	       				echo "Found matching orbit file: $orbit_match"
	       				ln -sf $orbits_PATH/$orbit_match $work_PATH/raw/
					echo $orbit_match
	       				break
	       			    else
	       				# No match again, get prepared for another round
	       				prev_orbit=$orbit
	       				prev_orbit_startdate=$orbit_startdate 
				    fi 
				    
				fi

			    fi

			fi
			
			
			((orbit_counter++))
		    done
		    



		    if [ ! "$orbit_match" == "none" ]; then
			for swath in ${swaths_to_process[@]}; do

			    cd $work_PATH/orig/$current_file/annotation/
			    name_stem=$(ls *iw$swath*); name_stem=${name_stem::-4}
			    cd $work_PATH/orig/$prev_file/annotation/
			    prev_name_stem=$(ls *iw$swath*); prev_name_stem=${prev_name_stem::-4}
			    cd ..			
			    
			    if [ ${name_stem:24:6} -gt ${prev_name_stem:24:6} ]; then			    			    
				stem_1=$name_stem
				file_1=$current_file
				stem_2=$prev_name_stem
				file_2=$prev_file
			    else
				stem_1=$prev_name_stem
				file_1=$prev_file
				stem_2=$name_stem
				file_2=$current_file
			    fi			
			    
			    cd $work_PATH/orig_cut/temp/
			    # Obtain radar coordinates for area of interest coordinates (s. config file)		

			    ln -sf $work_PATH/orig/$file_1/measurement/${stem_1}.tiff .
			    ln -sf $work_PATH/orig/$file_1/annotation/${stem_1}.xml .
			    ln -sf $work_PATH/orig/$file_2/measurement/${stem_2}.tiff .
			    ln -sf $work_PATH/orig/$file_2/annotation/${stem_2}.xml .
			    
			    # Generate PRM files
			    make_s1a_tops ${stem_1}.xml ${stem_1}.tiff ${stem_1} 0
			    make_s1a_tops ${stem_2}.xml ${stem_2}.tiff ${stem_2} 0
			    
			    # Read radar coordinates for AoI
			    azimuth_1=$( echo "$lon_1 $lat_1 $elev_1" | SAT_llt2rat ${stem_2}.PRM 0 | awk '{print $2}' )
			    azimuth_2=$( echo "$lon_2 $lat_2 $elev_2" | SAT_llt2rat ${stem_2}.PRM 0 | awk '{print $2}' )

			    if [ "$debug" -ge 1 ]; then 
				echo "Stem 1: $stem_1"		
				echo "Stem 2: $stem_2"; echo
				echo "current id: ${name_stem:24:6}"
				echo "previous id: ${prev_name_stem:24:6}"; echo
				echo "Azimuth for $lon_1 $lat_1 $elev_1 is $azimuth_1"
				echo "Azimuth for $lon_2 $lat_2 $elev_2 is $azimuth_2"
			    fi
			    
			    # Assemble and cut scenes
			    if [ "${azimuth_1%.*}" -gt "${azimuth_2%.*}" ]; then
				# echo "Az 1 > Az 2 - Executing assemble_tops $azimuth_2 $azimuth_1 $stem_1 $stem_2 ../$stem_2"
				assemble_tops $azimuth_2 $azimuth_1 $stem_2 $stem_1 ../$stem_2
			    else
				# echo "Az 2 >= Az 1 - Executing assemble_tops $azimuth_1 $azimuth_2 $stem_1 $stem_2 ../$stem_2"
				assemble_tops $azimuth_1 $azimuth_2 $stem_2 $stem_1 ../$stem_2
			    fi

			    prefix_1="${stem_1:15:8}_${stem_1:24:6}_F${swath}"
			    prefix_2="${stem_2:15:8}_${stem_2:24:6}_F${swath}"
			    
			    cd ..

			    # Generate new PRM files for assembled tops
			    make_s1a_tops ${stem_2}.xml ${stem_2}.tiff S1A$prefix_2 0
			    
			    # Generate LED files for assembled tops
			    if [ "$debug" -ge 1 ]; then echo "Executing ext_orb_s1a with option ${stem_2}.PRM $orbit_match ../$prefix_2"; fi
			    ext_orb_s1a S1A${prefix_2}.PRM $orbits_PATH/$orbit_match S1A$prefix_2
		    	    
			    # Prepare data in raw folder for subsequent processing steps ...
			    cd $work_PATH/raw/      		    		    
			    ln -sf $work_PATH/orig_cut/${stem_2}.xml .
			    ln -sf $work_PATH/orig_cut/${stem_2}.tiff .		    

			    # Write to data_in file
			    # Check if single_master mode and  current scene is master scene
			    if [ $process_intf_mode = "single_master" ]; then
				echo
				echo "Target date: ${target_scene:17:8}"
				echo "Master scene date: $master_scene_date"
				echo
				if [ "$master_scene_date" = "${target_scene:17:8}" ]; then
				    # master_scene=$target_scene; master_orbit=$orbit_match
				    # echo "HOORAY, we have found our master!"
				    echo "${stem_2}:$orbit_match" >> $work_PATH/raw/data_sm_swath$swath.master	    
				else	 
				    echo "${stem_2}:$orbit_match" >> $work_PATH/raw/data_sm_swath$swath.tmp		
				fi
			    else
				# TODO: include "both" mode -> sm + pairs	
				echo "${stem_2:15:8}-${stem_2}:$orbit_match" >> $work_PATH/raw/data_swath$swath.tmp			    
			    fi			

			done
		    else 
			echo "No matching orbit available for date ${target_scene:17:8}. Skipping ..."
		    fi
		fi
	    fi

	    cp -n $work_PATH/orig/$current_file/manifest.safe $work_PATH/raw/${current_file:17:8}_manifest.safe
	   
	    prev_file=$current_file
		
	    ((i++))

	done < "$work_PATH/orig_cut/temp/filelist.txt"

	if [ "$clean_up" -ge 1 ]; then
	    rm -r $work_PATH/orig_cut/temp/
	fi


    else
	
	# Process full swaths without cutting ...

	cd $work_PATH/orig
	counter=1
	for S1_package in $( ls -r ); do
            S1_file[$counter]=${S1_package:0:${#S1_package}-4}
            S1_date[$counter]=${S1_package:17:8}

	    
	    #S1_file=$current_file
	    target_scene=${S1_package:0:${#S1_package}}
	    target_sensor=$( echo ${target_scene:0:3} | tr '[:lower:]' '[:upper:]' )	    

	    if [ -z $target_scene ]; then
		echo "Skipping scene $target_scene ..."
	    else
		echo "$( date -d "${target_scene:17:8} ${target_scene:26:2}:${target_scene:28:2}:${target_scene:30:2}" '+%s'  )" 
		target_date=$( date -d "${target_scene:17:8} ${target_scene:26:2}:${target_scene:28:2}:${target_scene:30:2}" '+%s'  ) 
	    fi
            
	    if [ "$debug" -ge 1 ]; then
		echo
		echo Opening SAFE file: 
		echo $work_PATH/orig/${S1_file[$counter]}.SAFE
		echo
            fi
            
            cp $work_PATH/orig/${S1_file[$counter]}SAFE/manifest.safe $work_PATH/raw/${S1_package:17:8}_manifest.safe
            
            cd $work_PATH/orig/${S1_file[$counter]}SAFE/annotation/
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
		echo "SWATH NAME 1: ${swath_names[1]}"
		echo "SWATH NAME 2: ${swath_names[2]}"
		echo "SWATH NAME 3: ${swath_names[3]}"
            fi
            
            ln -sf $work_PATH/orig/${S1_file[$counter]}SAFE/annotation/*.xml .
            ln -sf $work_PATH/orig/${S1_file[$counter]}SAFE/measurement/*.tiff .
            

	    # orbit_match=$( find_matching_orbit ${S1_file[$counter]} $orbit_list )




	    orbit_counter=1
	    orbit_match="none"

	    for orbit in $orbit_list; do
		if [ ! -z "$orbit" ] && [ "${orbit:42:8}" != " " ]; then		
		    date_string="${orbit:42:8} ${orbit:51:2}:${orbit:53:2}:${orbit:55:2}"
		    orbit_startdate=$( date -d "$date_string" '+%s' )
		    orbit_starttime=${orbit:34:6}
		    orbit_sensor=${orbit:0:3}	    		
		    
		    if [ "$debug" -eq 2 ]; then
			echo "Now working on orbit #: $orbit_counter - $orbit"
			echo 'Orbit sensor: ' $orbit_sensor
			echo 'Orbit start date: ' $orbit_startdate
			echo 'Orbit start time: ' $orbit_starttime
		    fi		   			
		    
		    if [ "$orbit_sensor" == "$target_sensor" ]; then 
			if [ -z ${prev_orbit_startdate} ] || [ -z ${orbit_startdate} ]; then
			    echo "Orbit date not configured properly ($prev_orbit_startdate - $orbit_startdate)... Skipping."
			    prev_orbit=$orbit
			    prev_orbit_startdate=$orbit_startdate 
			else
			    if [ "$target_date" -ge "$prev_orbit_startdate" ]  &&  [ "$target_date" -lt "$orbit_startdate" ]; then
	       			# Looks like we found a matching orbit
	       			# TODO: perform further checks, e.g. end_date overlap
	       			
	       			orbit_match=$prev_orbit
	       			echo "Found matching orbit file: $orbit_match"
	       			ln -sf $orbits_PATH/$orbit_match $work_PATH/raw/
				echo $orbit_match
	       			break
	       		    else
	       			# No match again, get prepared for another round
	       			prev_orbit=$orbit
	       			prev_orbit_startdate=$orbit_startdate 
			    fi 
			    
			fi

		    fi

		fi
		
		
		((orbit_counter++))
	    done
	    



	    if [ ! "$orbit_match" == "none" ]; then
		for swath in ${swaths_to_process[@]}; do
		        # Check if single_master mode and  current scene is master scene
		    if [ $process_intf_mode = "single_master" ]; then
			echo
			echo "Target date: ${target_scene:17:8}"
			echo "Master scene date: $master_scene_date"
			echo
			if [ "$master_scene_date" = "${target_scene:17:8}" ]; then
			    # master_scene=$target_scene; master_orbit=$orbit_match
			    echo "HOORAY, we have found our master!"
			    echo "${target_scene}:$orbit_match" >> data_sm_swath$swath.master	    
			else	 
			    echo "${target_scene:name_stem}:$orbit_match" >> data_sm_swath$swath.tmp		
			fi
		    else
			data_name=${swath_names[$swath]}
		        data_year=${data_name:15:8}
			echo "${data_year}-${data_name}:$orbit_match" >> data_swath$swath.tmp
		    fi

		echo; printf " Name stem: ${swath_names[$swath]} \n Orbit match: $orbit_match \n Swath name: ${swath_names[$swath]} \n swath: $swath"

		done
	    else
		echo; echo "WARNING: No matching orbit found for scene $target_scene; Scene will be skipped."; echo
	    fi   
	    
	    ((counter++))
	 
	done

    fi

    for swath in ${swaths_to_process[@]}; do
	if [ $process_intf_mode = "single_master" ]; then
	    cat data_sm_swath$swath.master > data_sm_swath$swath.in
	    sort data_sm_swath$swath.tmp  >> data_sm_swath$swath.in  
	    # rm data_sm_swath$swath.tmp data_sm_swath$swath.master
	else
	    echo "Adding data_swath$swath.tmp to data_swath$swath.in"
	    sort data_swath$swath.tmp > data_swath${swath}_sorted.tmp
	    cut -c 10- < data_swath${swath}_sorted.tmp > data_swath$swath.in  
	    # rm data_swath$swath.tmp
	fi
    done
    
    counter=1
    while [ $counter -lt ${#S1_file[@]} ]; do
	echo "S1 file $counter: ${S1_file[$counter]}" 
	echo "S1 date $counter: ${S1_date[$counter]}"   
	echo 
	((counter++))
    done

fi

