#!/usr/bin/env bash

#################################################################
#
# Preparation of SAR data sets.
# Find matching orbits and write data.in files for each swath.
# 
# Usage: prepare_data.sh config_file
#
################################################################



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

    # Write coordinates file
    echo "$lon_1 $lat_1 " > $work_PATH/boundary-box.xy
    echo "$lon_2 $lat_2 " >> $work_PATH/boundary-box.xy
    echo "$lon_1 $lat_2 " >> $work_PATH/boundary-box.xy
    echo "$lon_2 $lat_1 " >> $work_PATH/boundary-box.xy
   
    gmt grdtrack $work_PATH/boundary-box.xy -G$work_PATH/topo/dem.grd > $work_PATH/boundary-box.xyz

    echo "$cut_to_aoi" > $work_PATH/cut_to_aoi.flag
    
    orbit_list=$( ls $orbits_PATH )

       
    mkdir -p $work_PATH/preprocessing/filelists
    mkdir -p $work_PATH/preprocessing/raw
    filelist_PATH="$work_PATH/preprocessing/filelists/filelist.txt"
    rm -f $filelist_PATH


    # Check whether there are scenes originating from the same pass in orig directory ...

    echo "Checking for multiple scenes originating from the same pass."
    cd $work_PATH/orig/
    
    scene_list=(*.SAFE)	
    i=0; 
    for scene in ${scene_list[@]}; do 
	echo $scene >> $filelist_PATH
	scene_dates[$i]=${scene:17:8}
	((i++))
    done	
    readarray -t scene_dates_sorted < <(printf '%s\0' "${scene_dates[@]}" | sort -z | xargs -0n1)
    scene_dates_unique=($(echo "${scene_dates_sorted[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    if [ "$debug" -ge 1 ]; then 
	echo; echo "Scene dates sorted:"
	echo "${scene_dates_sorted[@]}"
	echo; echo "Scene dates unique:"
	echo "${scene_dates_unique[@]}"
    fi
   
    
    for scene_date in ${scene_dates_unique[@]}; do
	

	# Check if there are multiple files for a date
	file_count=$( grep $scene_date $filelist_PATH | wc -l )

	echo; echo "Scene date: $scene_date"
	echo "File count: $file_count"
	
	orbit_match=()
	S1_files=()
	for ((i=1;i<=$file_count;++i)); do

	    S1_files[$i]=$( grep $scene_date $filelist_PATH | awk -v l="${i}" 'NR==l' )	    
	    S1_file=${S1_files[$i]}
	    echo "i: $i"
	    echo "S1_files[i]: ${S1_files[$i]}"
	    # echo "S1_file: ${S1_file}"
	    cp -n $work_PATH/orig/${S1_files[$i]}/manifest.safe $work_PATH/raw/${S1_files[$i]:17:8}_manifest.safe
	    target_sensor=$( echo ${S1_files[$i]:0:3} | tr '[:lower:]' '[:upper:]' )
	    target_date=$( date -d \
		"${S1_files[$i]:17:8} ${S1_files[$i]:26:2}:${S1_files[$i]:28:2}:${S1_files[$i]:30:2}" '+%s'  ) 
	    echo "Target date raw: ${S1_files[$i]:17:8} ${S1_files[$i]:26:2}:${S1_files[$i]:28:2}:${S1_files[$i]:30:2}"
	    echo "Target date sec: $target_date"

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

	done
	
	# If a matching orbits were found -> Prepare files and add to respective data.in files
	if [ ! "${orbit_match}" == "none" ]; then

	    for swath in ${swaths_to_process[@]}; do
		
		# Start the slice merge and burst cut procedure

		name_stems=()
		prefixes=()
		for S1_file in ${S1_files[@]}; do		   
		    cd $work_PATH/orig/${S1_file}/annotation/		    
		    tmp_stem=$(ls *iw$swath*)
		    name_stems+=(${tmp_stem::-4})
		done

		if [ $debug -ge 1 ]; then
		    echo; echo "Name stems:"
		    echo "${name_stems[@]}"
		fi
		
		# Sort stems by time
		rm -f $work_PATH/stem_list.tmp
		i=1
		for stem in ${name_stems[@]}; do
		    echo "${stem:24:6} $stem ${S1_files[$i]}" >> $work_PATH/stem_list.tmp
		    ((i++)) 
		done

		sort $work_PATH/stem_list.tmp > $work_PATH/stem_list_sorted.tmp
		stems_chrono=($( cat $work_PATH/stem_list_sorted.tmp | awk '{print $2}' ))
		files_chrono=($( cat $work_PATH/stem_list_sorted.tmp | awk '{print $3}' ))
		
		# cd $work_PATH/orig
		cd $work_PATH/preprocessing/raw

		i=0
		for stem in ${stems_chrono[@]}; do
		   
		    ln -sf $work_PATH/orig/${files_chrono[$i]}/measurement/${stem}.tiff .
		    ln -sf $work_PATH/orig/${files_chrono[$i]}/annotation/${stem}.xml .
		    make_s1a_tops ${stem}.xml ${stem}.tiff ${stem} 0
		    scene_prefix="${stem:15:8}_${stem:24:6}_F${swath}"
		    prefixes+=($scene_prefix)

		    if [ "$debug" -ge 1 ]; then 
			echo "Stem $i: $stem"		
			echo "Timestamp: ${stem:24:6}"
			echo "S1 file: ${files_chrono[$i]}"; echo
		    fi
		    ((i++))
		done

		stem=${stems_chrono[0]}
		scene_prefix=${prefixes[0]}
		if [ $debug -ge 1 ]; then
		    echo; echo "Main stem: $stem"
		    echo "Main scene prefix: $scene_prefix"
		fi
		# Obtain radar coordinates for area of interest coordinates (s. config file)		
		
		azimuth_1=$( awk 'NR==1' $work_PATH/boundary-box.xyz | SAT_llt2rat ${stem}.PRM 0 | awk '{print $2}' )
		azimuth_2=$( awk 'NR==2' $work_PATH/boundary-box.xyz | SAT_llt2rat ${stem}.PRM 0 | awk '{print $2}' )
		azimuth_3=$( awk 'NR==3' $work_PATH/boundary-box.xyz | SAT_llt2rat ${stem}.PRM 0 | awk '{print $2}' )
		azimuth_4=$( awk 'NR==4' $work_PATH/boundary-box.xyz | SAT_llt2rat ${stem}.PRM 0 | awk '{print $2}' )

		azimuth_min=$azimuth_1
		if [ $( echo "$azimuth_2 < $azimuth_min" | bc -l ) -eq 1 ]; then azimuth_min=$azimuth_2; fi
		if [ $( echo "$azimuth_3 < $azimuth_min" | bc -l ) -eq 1 ]; then azimuth_min=$azimuth_3; fi
		if [ $( echo "$azimuth_4 < $azimuth_min" | bc -l ) -eq 1 ]; then azimuth_min=$azimuth_4; fi
		
		azimuth_max=$azimuth_1
		if [ $( echo "$azimuth_2 > $azimuth_max" | bc -l ) -eq 1 ]; then azimuth_max=$azimuth_2; fi
		if [ $( echo "$azimuth_3 > $azimuth_max" | bc -l ) -eq 1 ]; then azimuth_max=$azimuth_3; fi
		if [ $( echo "$azimuth_4 > $azimuth_max" | bc -l ) -eq 1 ]; then azimuth_max=$azimuth_4; fi


		if [ "$debug" -ge 1 ]; then 
		    echo "Minimum azimuth in AOI is $azimuth_min"
		    echo "Maximum azimuth in AOI is $azimuth_max"
		fi
		
		# Assemble TOPS, omit burst outside AOI		
		stem_count=${#stems_chrono[@]}
		stem_string=""
		for((i=0;i<$stem_count;++i)); do
		    stem_string="$stem_string ${stems_chrono[$i]}"		    
		done
		
		if [ $debug -ge 1 ]; then
		    echo; echo "Executing assemble_tops with parameters:"
		    echo "$azimuth_min $azimuth_max $stem_string $work_PATH/preprocessing/$stem"
		fi
		assemble_tops $azimuth_min $azimuth_max $stem_string $work_PATH/preprocessing/$stem
			
		cd $work_PATH/preprocessing/

		# Generate new PRM files for assembled tops
		if [ $debug -ge 1 ]; then
		    echo; echo "Executing make_s1a_tops with parameters:"
		    echo "${stem}.xml ${stem}.tiff S1_${scene_prefix} 0"
		fi		
		make_s1a_tops ${stem}.xml ${stem}.tiff S1_${scene_prefix} 0
		
		# Generate LED files for assembled tops
		if [ "$debug" -ge 1 ]; then 
		    echo; echo "Executing ext_orb_s1a with parameter:"
		    echo "S1_${scene_prefix}.PRM $orbits_PATH/$orbit_match S1_$scene_prefix"
		fi
		ext_orb_s1a S1_${scene_prefix}.PRM $orbits_PATH/$orbit_match S1_$scene_prefix
		
		# Prepare data in raw folder for subsequent processing steps ...
		cd $work_PATH/raw/      		    		    
		ln -sf $work_PATH/preprocessing/${stem}.xml .
		ln -sf $work_PATH/preprocessing/${stem}.tiff .		    
		
		
		# Write to data_in file
		# Check if single_master mode and  current scene is master scene
		if [ $process_intf_mode = "single_master" ]; then
		    echo
		    echo "Target date: ${S1_files[$i]:17:8}"
		    echo "Master scene date: $master_scene_date"
		    echo
		    if [ "$master_scene_date" = "${S1_files[$i]:17:8}" ]; then				
			echo "${stem}:$orbit_match" >> $work_PATH/raw/data_sm_swath$swath.master	    
		    else	 
			echo "${stem}:$orbit_match" >> $work_PATH/raw/data_sm_swath$swath.tmp		
		    fi
		else
		    echo "${stem:15:8}-${stem}:$orbit_match" >> $work_PATH/raw/data_swath$swath.tmp	    
		fi			

	    done
	else 
	    echo "No matching orbit available. Skipping ..."
	    if [ $debug -ge 1 ]; then
		echo "Orbits found:"
		echo "${orbit_match[@]}"
	    fi
	fi

    done



    if [ "$clean_up" -ge 1 ]; then
	rm -r $work_PATH/preprocessing/filelists/
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

