#!/usr/bin/env bash

echo
echo "- - - - - - - - - - - - - - - - - - - -"
echo "Starting Sentinel-1 scene download ..."
echo "- - - - - - - - - - - - - - - - - - - -"
echo

echo "Area of interest boundary coordinates:"
echo "Longitude 1: $lon_1"
echo "Latitude 1:  $lat_1"
echo "Longitude 2: $lon_2"
echo "Latitude 2:  $lat_2"


# Check if all required data is available

if [ -z "$lon_1" ] || [ -z "$lat_1" ] || [ -z "$lon_2" ] || [ -z "$lat_2" ]; then
    echo; echo "ERROR: Missing area of interest coordinates:"
    echo "Please check configuration in ${config_file}."    
    aoi_ok=0
else
    # TODO: Add checks for value ranges (-180 to 180, -90 to 90)
    # TODO: Check if values are valid float numbers
    echo "Boundary coordinates accepted"
    aoi_ok=1
fi

if [ "$scene_provider" = "ESA" ]; then
    echo; echo "Data provider set to ESA's DHuS API"

    if [ -z "$ESA_username" ] || [ -z "$ESA_password" ]; then
	echo; echo "ERROR: Missing ESA login credentials."
	echo "Please review your login credentials file."
	login_ok=0
    else
	echo "Found ESA login credentials"
	login_ok=1
    fi
elif [ "$scene_provider" = "ASF" ]; then
    echo; echo "Data provider set to ASF EarthData API"

    if [ -z "$ASF_username" ] || [ -z "$ASF_password" ]; then
	echo; echo "ERROR: Missing ASF login credentials."
	echo "Please review your login credentials file."
	login_ok=0
    else
	echo "Found ASF login credentials"
	login_ok=1
    fi
fi


# If everything is ok, start the download

if [ "$aoi_ok" -eq 1 ] && [ "$login_ok" -eq 1 ]; then
    if [ "$scene_provider" = "ESA" ]; then
	dhusget_config="-u $ESA_username -p $ESA_password"

	area_of_interest="${lon_1},${lat_1}:${lon_2},${lat_2}"
	
	if [ ! -z "$download_option" ]; then dhusget_config="$dhusget_config -o $download_option"; else dhusget_config="$dhusget_config -o product"; fi
	if [ ! -z "$mission" ]; then dhusget_config="$dhusget_config -m $mission"; else dhusget_config="$dhusget_config -m Sentinel-1"; fi
	if [ ! -z "$instrument" ]; then dhusget_config="$dhusget_config -i $instrument"; fi # else dhusget_config="$dhusget_config -i SAR"; fi
	if [ ! -z "$sensing_period_start" ]; then dhusget_config="$dhusget_config -S $sensing_period_start"; fi
	if [ ! -z "$sensing_period_end" ]; then dhusget_config="$dhusget_config -E $sensing_period_end"; fi
	if [ ! -z "$ingestion_period_start" ]; then dhusget_config="$dhusget_config -s $ingestion_period_start"; fi
	if [ ! -z "$ingestion_period_end" ]; then dhusget_config="$dhusget_config -e $ingestion_period_end"; fi
	if [ ! -z "$area_of_interest" ]; then dhusget_config="$dhusget_config -c $area_of_interest"; fi
	if [ ! -z "$relative_orbit" ]; then dhusget_config="$dhusget_config -F relativeorbitnumber:$relative_orbit"; fi
	# if [ ! -z "$search_string" ]; then dhusget_config="$dhusget_config -F $search_string"; fi
	if [ ! -z "$product_type" ]; then dhusget_config="$dhusget_config -T $product_type"; else dhusget_config="$dhusget_config -T SLC"; fi
	#if [ ! -z "$info_file_destination" ]; then dhusget_config="$dhusget_config -q $info_file_destination -C $info_file_destination" ; fi
	if [ ! -z "$max_results_per_page" ]; then dhusget_config="$dhusget_config -l $max_results_per_page"; else dhusget_config="$dhusget_config -l 100"; fi
	if [ ! -z "$concurrent_downloads" ]; then dhusget_config="$dhusget_config -n $concurrent_downloads"; else dhusget_config="$dhusget_config -n 2"; fi

	# dhusget_config="$dhusget_config -q $input_PATH -C $input_PATH"
	dhusget_config="$dhusget_config -O $input_PATH"

	echo
	echo "DHuSget configuration:"
	echo $dhusget_config
	echo

	cd $OSARIS_PATH/lib/ext/dhusget/
	./dhusget.sh $dhusget_config

    elif [ "$scene_provider" = "ASF" ]; then
	echo "Downloading from ASF"
		
	cd $input_PATH
	ASF_call="https://api.daac.asf.alaska.edu/services/search/param?"
	ASF_call="${ASF_call}polygon=${lon_1},${lat_1},${lon_1},${lat_2},${lon_2},${lat_2},${lon_2},${lat_1},${lon_1},${lat_1}"
	ASF_call="${ASF_call}&platform=Sentinel-1A,Sentinel-1B"
# polygon=-57.1,-17.83,-57.1,-18.8,-56.6,-18.8,-56.6,-17.83,-57.1,-17.83\
# &platform=Sentinel-1A,Sentinel-1B\
# &start=2017-10-01T00:00:00UTC\&end=2019-01-01T00:00:00UTC\&processingLevel=SLC\&relativeOrbit=141\&maxResults=10\&output=csv

	if [ ! -z "$sensing_period_start" ]; then ASF_call="${ASF_call}&start=${sensing_period_start::-5}UTC"; fi
	if [ ! -z "$sensing_period_end" ]; then ASF_call="${ASF_call}&end=${sensing_period_end::-5}UTC"; fi
	# if [ ! -z "$ingestion_period_start" ]; then ASF_call="${ASF_call}&processingDate=${ingestion_period_start::-5}UTC"; fi
	# if [ ! -z "$ingestion_period_end" ]; then ASF_call="${ASF_call}&____=${ingestion_period_end}UTC"; fi
       
	ASF_call="${ASF_call}&processingLevel=SLC"
	if [ ! -z "$relative_orbit" ]; then ASF_call="${ASF_call}&relativeOrbit=${relative_orbit}"; fi
	ASF_call="${ASF_call}&output=csv"

	if [ $debug -ge 1 ]; then
	    echo; echo "ASF call:"
	    echo "$ASF_call"
	fi
	echo $ASF_call | xargs curl  > asf.csv

	ASF_files=($( cat asf.csv | awk -F"," '{if (NR>1) print $27}' | awk -F'"' '{print $2}' ))

	if [ $debug -ge 1 ]; then
	    echo; echo "Files to download:"
	    for ASF_file in ${ASF_files[@]} ]; do
		echo "${ASF_files[@]}"; echo
	    done
	fi

	for ASF_file in ${ASF_files[@]}; do	    
	    wget --http-user=$ASF_username --http-password=$ASF_password -nc $ASF_file	    
	done			    
	
    fi

else
    echo "Skipping S1 scene download ..."; echo
fi
    
