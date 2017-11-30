#!/bin/bash

echo
echo "- - - - - - - - - - - - - - - - - - - -"
echo "Starting Sentinel download ..."
echo "- - - - - - - - - - - - - - - - - - - -"
echo

OSARIS_PATH=/home/loibldav/Git/osaris
input_PATH=/data/scratch/loibldav/S1-archive/Golubin-DSC-orbit_106-pass_4
import_data_type=search_string

urlencode() {
    # urlencode <string>
    old_lc_collate=$LC_COLLATE
    LC_COLLATE=C
    
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done
    
    LC_COLLATE=$old_lc_collate
}


username="slingshot"
password="esa@ADALbertSTEINweg80AC!"

# download_string='(%20footprint:"Intersects(POLYGON((74.32613533801684%2042.09165163084839,75.01325803171174%2042.09165163084839,75.01325803171174%2042.838794204226474,74.32613533801684%2042.838794204226474,74.32613533801684%2042.09165163084839)))"%20AND%20(%20beginPosition:[2015-12-01T00:00:00.000Z%20TO%20NOW]%20AND%20endPosition:[2015-12-01T00:00:00.000Z%20TO%20NOW]%20)%20AND%20(platformname:Sentinel-1%20AND%20producttype:SLC%20AND%20sensoroperationalmode:IW%20AND%20relativeorbitnumber:107%20AND%20slicenumber:3%20)'

search_string='( footprint:"Intersects(POLYGON((74.32613533801684 42.09165163084839,75.01325803171174 42.09165163084839,75.01325803171174 42.838794204226474,74.32613533801684 42.838794204226474,74.32613533801684 42.09165163084839)))" ) AND ( beginPosition:[2015-12-01T00:00:00.000Z TO NOW] AND endPosition:[2015-12-01T00:00:00.000Z TO NOW] ) AND (platformname:Sentinel-1 AND producttype:SLC AND sensoroperationalmode:IW AND relativeorbitnumber:106 AND slicenumber:4 )'

# search_string_encoded=$(urlencode "$search_string")

lon_min=74.326
lon_max=75.013
lat_min=42.091
lat_max=42.839

rel_orbit=107
slice=3

mission=Sentinel-1

ingestion_from=2015-12-01T00:00:00.000Z
ingestion_to=NOW


download_option="product"
# Options: product - manifest - all

concurrent_downloads=2

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
    # echo "Search string: $search_string"
    # echo "Search string envcoded: $search_string_encoded"
    dhusget_config="$dhusget_config -l 100 -o $download_option -n $concurrent_downloads -F $search_string' -O $input_PATH"

elif [ "$import_data_type" == "single_opt" ]; then
    echo "Querying DHuS with single options"
    
    dhusget_config="$dhusget_config -l 200 -o $download_option -n $concurrent_downloads -m $mission -s $ingestion_from -e $ingestion_to -c $lon_min,$lat_min:$lon_max,$lat_max -T SLC -O $input_PATH"

else
    echo "Error"
    echo "No download configuration specified!"
    echo "Please set <input_file_type> in config.txt ..."
fi


echo
echo "DHuSget configuration:"
echo $dhusget_config
echo

#cd $OSARIS_PATH/lib/ext/dhusget/
#./mod_dhusget.sh $dhusget_config

#-F "'relativeorbitnumber:$rel_orbit AND slicenumber:$slice'"
