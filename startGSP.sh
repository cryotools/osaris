#!/bin/bash

debug=1

# - - - - - - - - - - - - - - - -
# Loading configuration          
# - - - - - - - - - - - - - - - -
echo
echo Configuring GSP ...

GSP_directory=$( pwd )
echo "GSP directory: $GSP_directory" 
echo

echo "Reading configuration file" 
source config.txt
echo "Username: $username" 
echo "dhusget.sh path: $dhusget_path" 

if [ ! -d $input_PATH ]; then
  mkdir -p $input_PATH;
fi

if [ ! -d $orbits_PATH ]; then
  mkdir -p $orbits_PATH;  
fi

if [ ! -d $work_PATH ]; then
  mkdir -p $work_PATH;
fi

if [ ! -d $work_PATH/raw ]; then
  mkdir -p $work_PATH/raw;
fi

if [ ! -d $output_PATH ]; then
  mkdir -p $output_PATH;
fi

# ln -s $orbits_PATH/*.EOF $work_PATH/raw/ 
ln -s $topo_PATH/dem.grd $work_PATH/raw/

log_filename=GSP-log-$( date +"%Y-%m-%d_%Hh%mm" ).txt
err_filename=GSP-errors-$( date +"%Y-%m-%d_%Hh%mm" ).txt
logfile=$output_PATH$log_filename
errfile=$output_PATH$err_filename
echo "Log will be written to $logfile"
echo "Errors will be written to $errfile"
echo


1>>$logfile
2>>$errfile

# - - - - - - - - - - - - - - - -
# Download required files
# - - - - - - - - - - - - - - - -

if [ $input_files = "download" ]; then


    echo
    echo Starting Sentinel1 file download ...


    if [ $use_filelist = "true" ]; then
        download_config="-r $GSP_directory/$filelist"
    else
        download_config=$download_string
    fi

    echo
    echo "Starting dhusget with the following configuration:"
    echo "-u $username -p $password -o $download_option -n $concurrent_downloads -O $input_PATH $download_config"
    echo

    cd $dhusget_PATH 
    ./dhusget.sh -u $username -p $password -o $download_option -n $concurrent_downloads -O $input_PATH $download_config

fi

# Update orbits when requested
if [ "$update_orbits" -eq 1 ]; then
    echo
    echo Updating orbit data ...
    wget --no-clobber -r -nH -nd -np -R index.html* -P $orbits_PATH http://www.unavco.org/data/imaging/sar/lts1/winsar/s1qc/aux_poeorb/ > $logfile 
    # --wait=3 --limit-rate=1000K  
fi	        

# - - - - - - - - - - - - - - - -
# Prepare SAR data sets
# - - - - - - - - - - - - - - - -
echo
echo Preparing SAR data sets ... 

cd $work_PATH/raw/  
rm -f data.in
touch data.in

cd $input_PATH
counter=1
for S1_package in $( ls ); do
    
    # Check if S1_package is valid S1 data directory
    if [[ $S1_package =~ ^S1.* ]]; then
            
        echo Extracting $S1_package ... 
        cd $input_PATH   
        unzip $S1_package -x *-vh-* -d $work_PATH/orig/
        #echo tar xvf $i -C $work_PATH
        
        #echo ${S1_package:0:${#S1_package}-4}
        S1_file[$counter]=${S1_package:0:${#S1_package}-4}
        #echo ${S1_package:17:8}
        S1_date[$counter]=${S1_package:17:8}
        
        echo $work_PATH/${S1_file[$counter]}.SAFE
        echo

        cp $work_PATH/orig/${S1_file[$counter]}.SAFE/manifest.safe $work_PATH/raw/${S1_package:17:8}_manifest.safe
        
        cd $work_PATH/orig/${S1_file[$counter]}.SAFE/annotation/
        swath_names=($( ls *.xml ))
                                
        
        cd $work_PATH/raw/      
        
        # in order to correct for Elevation Antenna Pattern Change, cat the manifest and aux files to the xmls
	# delete the first line of the manifest file as it's not a typical xml file.
        awk 'NR>1 {print $0}' < ${S1_package:17:8}_manifest.safe > tmp_file
	cat $work_PATH/orig/${S1_file[$counter]}.SAFE/annotation/${swath_names[0]} tmp_file $work_PATH/orig/s1a-aux-cal.xml > ./${swath_names[0]}
	
	swath_counter=0
        for swath in ${swath_names[@]}; do
            swath_names[$swath_counter]=${swath::-4}
            ((swath_counter++))
        done
        
        if [ "$debug" -eq 1 ]; then
            echo "SWATH NAME 0: ${swath_names[0]}"
            echo "SWATH NAME 1: ${swath_names[1]}"
            echo "SWATH NAME 2: ${swath_names[2]}"
        fi
                      
        ln -s $work_PATH/orig/${S1_file[$counter]}.SAFE/annotation/*.xml .
        ln -s $work_PATH/orig/${S1_file[$counter]}.SAFE/measurement/*.tiff .
        

        
        # Find adequate orbit files and add symlinks        			
	orbit_list=$( ls $orbits_PATH )

	target_scene=${S1_file[$counter]}
	target_sensor=$( echo ${target_scene:0:3} | tr '[:lower:]' '[:upper:]' )
	target_date=$( date -d "${target_scene:17:8} ${target_scene:26:2}:${target_scene:28:2}:${target_scene:30:2}" '+%s'  )
	
	if [ "$debug" -eq 1 ]; then
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
	    
	    if [ "$debug" -eq 1 ]; then
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
	
	echo "${swath_names[0]}:$orbit_match" >> data.in
	
	#case "$gmtsar_mode" in
	#    batch)
        #	echo "${swath_names[0]}:$orbit_match" >> data.in
    	#    ;;    
    	#    single-pair)
        #	echo "${swath_names[0]}:$orbit_match" >> data.in
    	#    ;;
        #    
        #    *)
        #	echo "Unknown value for gmtsar_mode. Please check config.txt"
        #	exit 1
 
	#esac		
		
	((counter++))
    fi
done

counter=1
while [ $counter -lt ${#S1_file[@]} ]; do
    echo "S1 file $counter: ${S1_file[$counter]}" 
    echo "S1 date $counter: ${S1_date[$counter]}"   
    echo 
    ((counter++))
done

# - - - - - - - - - - - - - - - -
# Start GMTSAR processing
# - - - - - - - - - - - - - - - -

case "$SAR_sensor" in
    Sentinel)
        source $GSP_directory/processSentinel.sh
    ;;    
    
    *)
        #echo $"Usage: $0 {start|stop|restart|condrestart|status}"
        exit 1
 
esac


echo
echo - - - - - - - - - - - - - - - -
echo Writing reports
echo - - - - - - - - - - - - - - - -
echo

echo
echo - - - - - - - - - - - - - - - -
echo Cleaning up
echo - - - - - - - - - - - - - - - -
echo
