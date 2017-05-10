#!/bin/bash

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
echo "dhusget.sh path: $dhusget_PATH" 

rm -rf $work_PATH/raw
rm -rf $work_PATH/F*

mkdir -pv $input_PATH
mkdir -pv $orbits_PATH
mkdir -pv $work_PATH
mkdir -pv $work_PATH/raw
mkdir -pv $output_PATH
mkdir -pv $log_PATH

# ln -s $orbits_PATH/*.EOF $work_PATH/raw/ 
ln -s $topo_PATH/dem.grd $work_PATH/raw/

#log_filename=GSP-log-$( date +"%Y-%m-%d_%Hh%mm" ).txt
#err_filename=GSP-errors-$( date +"%Y-%m-%d_%Hh%mm" ).txt
#logfile=$log_PATH/$log_filename
#errfile=$log_PATH/$err_filename
#echo "Log will be written to $logfile"
#echo "Errors will be written to $errfile"
#echo

#cmd >$logfile 2>$errfile

# - - - - - - - - - - - - - - - -
# Download required files
# - - - - - - - - - - - - - - - -

if [ $input_files = "download" ]; then

    echo
    echo Starting Sentinel1 file download ...
    
    dhusget_config="-u $username -p $password"

    if [ "$import_data_type" == "meta4" ]; then
	echo "Reading DHuS download configuration from meta4 file $meta4_file"
	python $GSP_directory/lib/meta4-to-filelist.py $meta4_file $filelist_file
	dhusget_config="$dhusget_config -E 2010-10-10T12:00:00.000Z -o $download_option -n $concurrent_downloads -O $input_PATH -r $filelist_file"

    elif [ "$import_data_type" == "filelist" ]; then
	echo "Reading DHuS download configuration from filelist $filelist_file"
	dhusget_config="$dhusget_config -E 2010-10-10T12:00:00.000Z -o $download_option -n $concurrent_downloads -O $input_PATH -r $filelist_file"

    elif [ "$import_data_type" == "search_string" ]; then
	echo "Querying DHuS with search string"
	echo $download_string
	dhusget_config="$dhusget_config -l 100 $download_string -o $download_option -n $concurrent_downloads -O $input_PATH"

    else
        echo "Error"
	echo "No download configuration specified!"
	echo "Please set <input_file_type> in config.txt ..."
    fi


    echo
    echo "Starting dhusget with the following configuration:"
    echo $dhusget_config
    echo

    cd $GSP_directory/lib/
    ./dhusget.sh $dhusget_config

fi

# Update orbits when requested
if [ "$update_orbits" -eq 1 ]; then
    echo
    echo Updating orbit data ...
    wget --no-clobber -r -nH -nd -np -R index.html* -P $orbits_PATH http://www.unavco.org/data/imaging/sar/lts1/winsar/s1qc/aux_poeorb/  
    # --wait=3 --limit-rate=1000K  
fi	        

# - - - - - - - - - - - - - - - -
# Prepare SAR data sets
# - - - - - - - - - - - - - - - -
echo
echo Preparing SAR data sets ... 

#cd $work_PATH/raw/  
#rm -f data.in
#touch data.in

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
	       	    orbit_match="NaN"
	       	    break
	       	else
	       	    # No match again, get prepared for another round
	       	    prev_orbit=$orbit
	       	    prev_orbit_startdate=$orbit_startdate 
		fi
	    fi
		        
	    ((orbit_counter++))
	done
	
	if [ $orbit_match = "NaN" ]; then
	    echo 
	    echo "WARNING:"
	    echo "No matching orbit found. Processing not possible!" # TODO: Skip pair
	    echo "Please check orbit download configuration and orbit download folder."
	    echo
	fi

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
