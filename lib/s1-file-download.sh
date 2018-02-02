#!/bin/bash

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






 # echo "   -m <mission name>		: Sentinel mission name. Possible options are: Sentinel-1, Sentinel-2, Sentinel-3);"
 # echo ""
 # echo "   -i <instrument name>		: instrument name. Possible options are: SAR, MSI, OLCI, SLSTR, SRAL);"
 # echo ""
 # echo "   -t <time in hours>		: search for products ingested in the last <time in hours> (integer) from the time of"
 # echo " 				  execution of the script."
 # echo "   				  (e.g. '-t 24' to search for products ingested in the last 24 Hours);"
 # echo ""
 # echo "   -s <ingestion_date_FROM>	: Search for products ingested ${bold}after${normal} the date and time specified by <ingestion_date_FROM>."  
 # echo "   				  The date format is ISO 8601, YYYY-MM-DDThh:mm:ss.cccZ (e.g. -s 2016-10-02T06:00:00.000Z);"
 # echo "" 
 # echo "   -e <ingestion_date_TO>	: Search for products ingested ${bold}before${normal} the date specified by <ingestion_date_TO>."
 # echo "   				  The date format is ISO 8601, YYYY-MM-DDThh:mm:ss.cccZ (e.g. -e 2016-10-10T12:00:00.000Z);"
 # echo "" 
 # echo "   -S <sensing_date_FROM>	: Search for products with sensing date ${bold}greater than${normal} the date and time specified by <sensing_date_FROM>."
 # echo "   				  The date format is ISO 8601, YYYY-MM-DDThh:mm:ss.cccZ (e.g. -S 2016-10-02T06:00:00.000Z);"
 # echo "" 
 # echo "   -E <sensing_date_TO>		: Search for products with sensing date ${bold}less than${normal} the date and time specified by <sensing_date_TO>."
 # echo "   				  The date format is ISO 8601, YYYY-MM-DDThh:mm:ss.cccZ (e.g. -E 2016-10-10T12:00:00.000Z);"
 # echo ""
 # echo "   -f <ingestion_date_file>	: Search for products ingested after the date and time provided through an input file. This option overrides option -s"
 # echo "   				  The date format shall be ISO 8601 (YYYY-MM-DDThh:mm:ss.cccZ)." 
 # echo "   				  <ingestion_date_file> is automatically updated at the end of the script execution" 
 # echo "   				  with the ingestion date of the last sucessfully downloaded product;"
 # echo " "
 # echo "   -c <lon1,lat1:lon2,lat2> 	: Search for products intersecting a rectangular Area of Interst (or Bounding Box)"
 # echo "   				  by providing the geographical coordinates of two opposite vertices. "
 # echo "   				  Coordinates need to be provided in Decimal Degrees and with the following syntax:"
 # echo " "
 # echo "   				     -    ${bold}lon1,lat1:lon2,lat2${normal}"
 # echo " "
 # echo "   				  where lon1 and lat1 are respectively the longitude and latitude of the first vertex and"
 # echo "  				  lon2 and lat2 the longitude and latitude of the second vertex."
 # echo "   				  (e.g. '-c -4.530,29.850:26.750,46.800' is a bounding box enclosing the Mediterranean Sea);"
 # echo " "
 # echo "   -T <product type>		: Search products according to the specified product type."
 # echo "   				  Sentinel-1 possible options are:  SLC, GRD, OCN and RAW. "
 # echo "   				  Sentinel-2 posiible option is: S2MSI1C ;"
 # echo " "
 # echo "   -F <free OpenSearch query>	: free text OpenSearch query. The query must be written enclosed by single apexes '<query>'. "
 # echo "   				  (e.g. -F 'platformname:Sentinel-1 AND producttype:SLC'). "
 # echo "   				  Note: the free text OpenSearch query is in ${bold}AND${normal} with the other possible sspecified search options." 
 # echo " "
 # echo " "
 # echo "  ${bold}SEARCH RESULT OPTIONS:${normal}"
 # echo " "
 # echo "   -l <results>			: maximum number of results per page [1,2,3,4,..]; default value = 25"
 # echo " "
 # echo "   -P <page>			: page number [1,2,3,4,..]; default value = 1"
 # echo " "
 # echo "   -q <XMLfile>			: write the OpenSearch query results in a specified XML file. Default file is './OSquery-result.xml'"
 # echo " "
 # echo "   -C <CSVfile>			: write the list of product results in a specified CSV file. Default file is './products-list.csv'"
 # echo " "
 # echo " "
 # echo "  ${bold}DOWNLOAD OPTIONS:${normal}"
 # echo " "
 # echo "   -o <download>		: THIS OPTION IS MANDATORY FOR DOWNLOADING. Accepted values for <download> are:"
 # echo "   				  	-  ${bold}product${normal} : download the Product ZIP files (manifest file included)"
 # echo "   				  	-  ${bold}manifest${normal} : download only the manifest files"
 # echo "   				  	-  ${bold}all${normal} : download both the Product ZIP files and the manifest files, and"
 # echo "   				  		 provide them in separate folders."
 # echo ""
 # echo "   				  	  By default the Product ZIP files are stored in ./product"
 # echo "   				   	  unless differently specified by option ${bold}-O${normal}."
 # echo ""
 # echo "   				  	  By default the manifest files are stored in ./manifest ;"

 # echo " "
 # echo " "
 # echo "   -O <folder>			: save the Product ZIP files in a specified folder. "
 # echo " "
 # echo "   -N <1...n>			: set number of wget download retries. Default value is 5. Fatal errors like 'connection refused'"
 # echo "   				  or 'not found' (404), are not retried;"
 # echo " "
 # echo "   -R <file>			: write in <file> the list of products that have failed the MD5 integrity check."
 # echo "   				  By default the list is written in ./failed_MD5_check_list.txt ;"
 # echo "   				  The format of the output file is compatible with option ${bold}-r${normal} ;"
 # echo " "
 # echo "   -D  				: if specified, remove the products that have failed the MD5 integrity check from disk."
 # echo "   				  By deafult products are not removed;"
 # echo " "
 # echo "   -r <file>			: download the products listed in an input <file> written according to the following format:"
 # echo "   				  - One product per line."
 # echo "   				  - <space><one character><space><UUID><space><one character><space><filename>."
 # echo "   			Examples:"
 # echo "   			' x 67c7491a-d98a-4eeb-9ca0-8952514c7e1e x S1A_EW_GRDM_1SSH_20160411T113221_20160411T113257_010773_010179_7BE0'"
 # echo "   			' 0 67c7491a-d98a-4eeb-9ca0-8952514c7e1e 0 S1A_EW_GRDM_1SSH_20160411T113221_20160411T113257_010773_010179_7BE0'"
 # echo " "
 # echo "   -L <lock folder>		: by default only one instance of dhusget can be executed at a time. This is ensured by the creation"
 # echo "   				  of a temporary lock folder $HOME/dhusget_tmp/lock which is removed a the end of each run."
 # echo "   				  For running more than one dhusget instance at a time is sufficient to assign different lock folders"
 # echo "   				  using the -L option (e.g. '-L foldername') to each dhusget instance;"
 # echo " "
 # echo "   -n <1...n>			: number of concurrent downloads (either products or manifest files). Default value is 2; this value"
 # echo "   				  doesn't override the quota limit set on the server side for the user"
 # echo " "

