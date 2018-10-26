#!/usr/bin/env bash

echo
echo "- - - - - - - - - - - - - - - - - - - -"
echo "Starting Sentinel download ..."
echo "- - - - - - - - - - - - - - - - - - - -"
echo

dhusget_config="-u $username -p $password"


if [ ! -z "$download_option" ]; then dhusget_config="$dhusget_config -o $download_option"; fi
if [ ! -z "$mission" ]; then dhusget_config="$dhusget_config -m $mission"; fi
if [ ! -z "$instrument" ]; then dhusget_config="$dhusget_config -i $instrument"; fi
if [ ! -z "$sensing_period_start" ]; then dhusget_config="$dhusget_config -S $sensing_period_start"; fi
if [ ! -z "$sensing_period_end" ]; then dhusget_config="$dhusget_config -E $sensing_period_end"; fi
if [ ! -z "$ingestion_period_start" ]; then dhusget_config="$dhusget_config -s $ingestion_period_start"; fi
if [ ! -z "$ingestion_period_end" ]; then dhusget_config="$dhusget_config -e $ingestion_period_end"; fi
if [ ! -z "$area_of_interest" ]; then dhusget_config="$dhusget_config -c $area_of_interest"; fi
if [ ! -z "$search_string" ]; then dhusget_config="$dhusget_config -F $search_string"; fi
if [ ! -z "$product_type" ]; then dhusget_config="$dhusget_config -T $product_type"; fi
#if [ ! -z "$info_file_destination" ]; then dhusget_config="$dhusget_config -q $info_file_destination -C $info_file_destination" ; fi
if [ ! -z "$max_results_per_page" ]; then dhusget_config="$dhusget_config -l $max_results_per_page"; fi
if [ ! -z "$concurrent_downloads" ]; then dhusget_config="$dhusget_config -n $concurrent_downloads"; fi

# dhusget_config="$dhusget_config -q $input_PATH -C $input_PATH"
dhusget_config="$dhusget_config -O $input_PATH"



echo
echo "DHuSget configuration:"
echo $dhusget_config
echo

cd $OSARIS_PATH/lib/ext/dhusget/
./dhusget.sh $dhusget_config
