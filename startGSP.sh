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

ln -s $orbits_PATH/*.EOF $work_PATH/raw/ 
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

# Update orbits
echo
echo Updating orbit data ...

wget --no-clobber -r -nH -nd -np -R index.html* -P $orbits_PATH http://www.unavco.org/data/imaging/sar/lts1/winsar/s1qc/aux_poeorb/ > $logfile 

# --wait=3 --limit-rate=1000K          

# - - - - - - - - - - - - - - - -
# Prepare SAR data sets
# - - - - - - - - - - - - - - - -
echo
echo Preparing SAR data sets ...

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
        
        cd $work_PATH/raw/   
        ln -s $work_PATH/orig/${S1_file[$counter]}.SAFE/annotation/*.xml .
        ln -s $work_PATH/orig/${S1_file[$counter]}.SAFE/measurement/*.tiff .
        
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
        cd $GSP_directory
        source processSentinel.sh
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
