#!/bin/bash

echo
echo "- - - - - - - - - - - - - - - - - - - -"
echo "Starting Sentinel download ..."
echo "- - - - - - - - - - - - - - - - - - - -"
echo

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
echo "DHuSget configuration:"
echo $dhusget_config
echo

cd $GSP_directory/lib/ext/dhusget/
./dhusget.sh $dhusget_config
