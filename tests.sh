#! /bin/bash

debug=1

orbits_PATH="/home/loibldav/Processing/S1-orbits"
orbit_list=$( ls $orbits_PATH )

target_scene="s1a-iw1-slc-vv-20160130t125846-20160130t125912-009724-00e32d-001"



	#target_scene=${S1_file[$counter]}
	target_sensor=$( echo ${target_scene:0:3} | tr '[:lower:]' '[:upper:]' )
	target_date=$( date -d "${target_scene:17:8} ${target_scene:26:2}:${target_scene:28:2}:${target_scene:30:2}" '+%s'  )
	
	if [ "$debug" -eq 1 ]; then
	    echo 'Target sensor: ' $target_sensor
	    echo 'Target date: ' $target_date
	fi    

	prev_orbit_startdate=0
	orbit_counter=1
	for orbit in $orbit_list; do
	    
	    orbit_startdate=$( date -d "${orbit:42:8} ${orbit:51:2}:${orbit:53:2}:${orbit:55:2}" '+%s' )
	    orbit_starttime=${orbit:34:6}
	    orbit_sensor=${orbit:0:3}
	    
	    if [ "$debug" -eq 1 ]; then
		echo "Now working on orbit #: $orbit_counter - $orbit"
		echo 'Orbit sensor: ' $orbit_sensor
		date -d "${orbit:42:8} ${orbit:51:2}:${orbit:53:2}:${orbit:55:2}"
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
