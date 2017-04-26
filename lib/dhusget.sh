#!/bin/bash

#-------------------------------------------------------------------------------------------	#
# Demo script illustrating some examples using the OData interface	#
# of the Data Hub Service (DHuS)                                                     	#
#-------------------------------------------------------------------------------------------	
# CHANGE LOG
# v0.3.1: 
#	- usage switch fixed
#	- usage text updated to include the download of Sentinel 2 products
# 	- introduction of parallel download with check of the server error messages (option -n)
#	- insertion of MD5 check 
#		
# Serco SpA 2015
# CHANGE LOG
# v0.3.2: 
#       - fixed "-f" option
#       - upgraded "-f" 
#       - added the following options: -s, -e, -S, -E, -F
#      
# CHANGE LOG
# v0.3.3: 
#       - added the following options: -O, -L, -R, -r
#   
# CHANGE LOG
# v0.3.4: 
#       - added the following options: -m, -i, -l, -P, -q, -C, -N, -D
#                     
# Serco SpA 2015
                                                                             	#
#-------------------------------------------------------------------------------------------	#
export VERSION=0.3.4

WD=$HOME/dhusget_tmp
PIDFILE=$WD/pid

test -d $WD || mkdir -p $WD 

#-

bold=$(tput bold)
normal=$(tput sgr0)
print_script=`echo "$0" | rev | cut -d'/' -f1 | rev`

function print_usage 
{ 
 print_script=`echo "$1" | rev | cut -d'/' -f1 | rev`
 echo " "
 echo "${bold}NAME${normal}"
 echo " "
 echo "  DHuSget $VERSION - The non interactive Sentinels product retriever from the Sentinels Data Hubs"
 echo " " 
 echo "${bold}USAGE${normal}"
 echo " "
 echo "  $print_script [LOGIN OPTIONS]... [SEARCH QUERY OPTIONS]... [SEARCH RESULT OPTIONS]... [DOWNLOAD OPTIONS]... "
 echo " "
 echo "${bold}DESCRIPTION${normal}"
 echo " "
 echo "  This script allows to get products from Sentinels Data Hubs executing query with different filter. The products can be visualized on shell and saved in list file"
 echo "  or downloaded in a zip file."
 echo "  Recommendation: If this script is run as a cronjob, to avoid traffic load, please do not schedule it exactly at on-the-clock hours (e.g 6:00, 5:00)."
 echo " "
 echo "${bold}OPTIONS"
 echo " "
 echo "  ${bold}LOGIN OPTIONS:${normal}"
 echo " "
 echo "   -d <DHuS URL>		: specify the URL of the Data Hub Service;"
 echo "   -u <username>		: data hub username;"
 echo "   -p <password>		: data hub password (note: if not provided by command line it is read by stdin);"
 echo " "
 echo " "
 echo "  ${bold}SEARCH QUERY OPTIONS:${normal}"
 echo " "
 echo "   -m <mission name>		: Sentinel mission name. Possible options are: Sentinel-1, Sentinel-2, Sentinel-3);"
 echo ""
 echo "   -i <instrument name>		: instrument name. Possible options are: SAR, MSI, OLCI, SLSTR, SRAL);"
 echo ""
 echo "   -t <time in hours>		: search for products ingested in the last <time in hours> (integer) from the time of"
 echo " 				  execution of the script."
 echo "   				  (e.g. '-t 24' to search for products ingested in the last 24 Hours);"
 echo ""
 echo "   -s <ingestion_date_FROM>	: Search for products ingested ${bold}after${normal} the date and time specified by <ingestion_date_FROM>."  
 echo "   				  The date format is ISO 8601, YYYY-MM-DDThh:mm:ss.cccZ (e.g. -s 2016-10-02T06:00:00.000Z);"
 echo "" 
 echo "   -e <ingestion_date_TO>	: Search for products ingested ${bold}before${normal} the date specified by <ingestion_date_TO>."
 echo "   				  The date format is ISO 8601, YYYY-MM-DDThh:mm:ss.cccZ (e.g. -e 2016-10-10T12:00:00.000Z);"
 echo "" 
 echo "   -S <sensing_date_FROM>	: Search for products with sensing date ${bold}greater than${normal} the date and time specified by <sensing_date_FROM>."
 echo "   				  The date format is ISO 8601, YYYY-MM-DDThh:mm:ss.cccZ (e.g. -S 2016-10-02T06:00:00.000Z);"
 echo "" 
 echo "   -E <sensing_date_TO>		: Search for products with sensing date ${bold}less than${normal} the date and time specified by <sensing_date_TO>."
 echo "   				  The date format is ISO 8601, YYYY-MM-DDThh:mm:ss.cccZ (e.g. -E 2016-10-10T12:00:00.000Z);"
 echo ""
 echo "   -f <ingestion_date_file>	: Search for products ingested after the date and time provided through an input file. This option overrides option -s"
 echo "   				  The date format shall be ISO 8601 (YYYY-MM-DDThh:mm:ss.cccZ)." 
 echo "   				  <ingestion_date_file> is automatically updated at the end of the script execution" 
 echo "   				  with the ingestion date of the last sucessfully downloaded product;"
 echo " "
 echo "   -c <lon1,lat1:lon2,lat2> 	: Search for products intersecting a rectangular Area of Interst (or Bounding Box)"
 echo "   				  by providing the geographical coordinates of two opposite vertices. "
 echo "   				  Coordinates need to be provided in Decimal Degrees and with the following syntax:"
 echo " "
 echo "   				     -    ${bold}lon1,lat1:lon2,lat2${normal}"
 echo " "
 echo "   				  where lon1 and lat1 are respectively the longitude and latitude of the first vertex and"
 echo "  				  lon2 and lat2 the longitude and latitude of the second vertex."
 echo "   				  (e.g. '-c -4.530,29.850:26.750,46.800' is a bounding box enclosing the Mediterranean Sea);"
 echo " "
 echo "   -T <product type>		: Search products according to the specified product type."
 echo "   				  Sentinel-1 possible options are:  SLC, GRD, OCN and RAW. "
 echo "   				  Sentinel-2 posiible option is: S2MSI1C ;"
 echo " "
 echo "   -F <free OpenSearch query>	: free text OpenSearch query. The query must be written enclosed by single apexes '<query>'. "
 echo "   				  (e.g. -F 'platformname:Sentinel-1 AND producttype:SLC'). "
 echo "   				  Note: the free text OpenSearch query is in ${bold}AND${normal} with the other possible sspecified search options." 
 echo " "
 echo " "
 echo "  ${bold}SEARCH RESULT OPTIONS:${normal}"
 echo " "
 echo "   -l <results>			: maximum number of results per page [1,2,3,4,..]; default value = 25"
 echo " "
 echo "   -P <page>			: page number [1,2,3,4,..]; default value = 1"
 echo " "
 echo "   -q <XMLfile>			: write the OpenSearch query results in a specified XML file. Default file is './OSquery-result.xml'"
 echo " "
 echo "   -C <CSVfile>			: write the list of product results in a specified CSV file. Default file is './products-list.csv'"
 echo " "
 echo " "
 echo "  ${bold}DOWNLOAD OPTIONS:${normal}"
 echo " "
 echo "   -o <download>		: THIS OPTION IS MANDATORY FOR DOWNLOADING. Accepted values for <download> are:"
 echo "   				  	-  ${bold}product${normal} : download the Product ZIP files (manifest file included)"
 echo "   				  	-  ${bold}manifest${normal} : download only the manifest files"
 echo "   				  	-  ${bold}all${normal} : download both the Product ZIP files and the manifest files, and"
 echo "   				  		 provide them in separate folders."
 echo ""
 echo "   				  	  By default the Product ZIP files are stored in ./product"
 echo "   				   	  unless differently specified by option ${bold}-O${normal}."
 echo ""
 echo "   				  	  By default the manifest files are stored in ./manifest ;"

 echo " "
 echo " "
 echo "   -O <folder>			: save the Product ZIP files in a specified folder. "
 echo " "
 echo "   -N <1...n>			: set number of wget download retries. Default value is 5. Fatal errors like 'connection refused'"
 echo "   				  or 'not found' (404), are not retried;"
 echo " "
 echo "   -R <file>			: write in <file> the list of products that have failed the MD5 integrity check."
 echo "   				  By default the list is written in ./failed_MD5_check_list.txt ;"
 echo "   				  The format of the output file is compatible with option ${bold}-r${normal} ;"
 echo " "
 echo "   -D  				: if specified, remove the products that have failed the MD5 integrity check from disk."
 echo "   				  By deafult products are not removed;"
 echo " "
 echo "   -r <file>			: download the products listed in an input <file> written according to the following format:"
 echo "   				  - One product per line."
 echo "   				  - <space><one character><space><UUID><space><one character><space><filename>."
 echo "   			Examples:"
 echo "   			' x 67c7491a-d98a-4eeb-9ca0-8952514c7e1e x S1A_EW_GRDM_1SSH_20160411T113221_20160411T113257_010773_010179_7BE0'"
 echo "   			' 0 67c7491a-d98a-4eeb-9ca0-8952514c7e1e 0 S1A_EW_GRDM_1SSH_20160411T113221_20160411T113257_010773_010179_7BE0'"
 echo " "
 echo "   -L <lock folder>		: by default only one instance of dhusget can be executed at a time. This is ensured by the creation"
 echo "   				  of a temporary lock folder $HOME/dhusget_tmp/lock which is removed a the end of each run."
 echo "   				  For running more than one dhusget instance at a time is sufficient to assign different lock folders"
 echo "   				  using the -L option (e.g. '-L foldername') to each dhusget instance;"
 echo " "
 echo "   -n <1...n>			: number of concurrent downloads (either products or manifest files). Default value is 2; this value"
 echo "   				  doesn't override the quota limit set on the server side for the user"
 echo " "
 echo " "
 echo " "
 echo "   'wget' is necessary to run the dhusget"
 echo " " 
 exit -1
}

function print_version 
{ 
	echo "dhusget $VERSION"
	exit -1
}

#----------------------
#---  Load input parameter
export DHUS_DEST="https://scihub.copernicus.eu/dhus"
export USERNAME=""
export PASSWORD=""
export TIME_SUBQUERY=""
export PRODUCT_TYPE=""
export INGEGESTION_TIME_FROM="1970-01-01T00:00:00.000Z"
export INGEGESTION_TIME_TO="NOW"
export SENSING_TIME_FROM="1970-01-01T00:00:00.000Z"
export SENSING_TIME_TO="NOW"
unset TIMEFILE


while getopts ":d:u:p:l:P:q:C:m:i:t:s:e:S:E:f:c:T:o:V:h:F:R:D:r:O:N:L:n:" opt; do
 case $opt in
	d)
		export DHUS_DEST="$OPTARG"
                export DHUS_DEST_IS_SET='OK'
		;;
	u)
		export USERNAME="$OPTARG"
		;;
	p)
		export PASSWORD="$OPTARG"
		;;
        l)
		export ROWS="$OPTARG"
		;;
	P)
		export PAGE="$OPTARG"
		;;
        q)
		export NAMEFILERESULTS="$OPTARG"
		;;
        C)
		export PRODUCTLIST="$OPTARG"
		;;
        m)
		export MISSION="$OPTARG"
		;;
	i)
		export INSTRUMENT="$OPTARG"
		;;
	t)
		export TIME="$OPTARG"
		export INGEGESTION_TIME_FROM="NOW-${TIME}HOURS"
                export isselected_filtertime_lasthours='OK'
		;;
        s)
                export TIME="$OPTARG"
		export INGEGESTION_TIME_FROM="$OPTARG"
                export isselected_filtertime_ingestion_date='OK'
                ;;
        e)
		export TIME="$OPTARG"
                export INGEGESTION_TIME_TO="$OPTARG"
                export isselected_filtertime_ingestion_date='OK'
                ;;	
        S)
		export SENSING_TIME="$OPTARG"
                export SENSING_TIME_FROM="$OPTARG"
                ;;
        E)
		export SENSING_TIME="$OPTARG"
                export SENSING_TIME_TO="$OPTARG"
                ;;
	f)
		export TIMEFILE="$OPTARG"
		if [ -s $TIMEFILE ]; then 		
			export INGEGESTION_TIME_FROM="`cat $TIMEFILE`"
		else
			export INGEGESTION_TIME_FROM="1970-01-01T00:00:00.000Z"
		fi
		;;
	c) 
		ROW=$OPTARG

		FIRST=`echo "$ROW" | awk -F\: '{print \$1}' `
		SECOND=`echo "$ROW" | awk -F\: '{print \$2}' `

		#--
		export x1=`echo ${FIRST}|awk -F, '{print $1}'`
		export y1=`echo ${FIRST}|awk -F, '{print $2}'`
		export x2=`echo ${SECOND}|awk -F, '{print $1}'`
		export y2=`echo ${SECOND}|awk -F, '{print $2}'`
		;;

	T)
		export PRODUCT_TYPE="$OPTARG"
		;;
	o)
		export TO_DOWNLOAD="$OPTARG"
		;;
	V)
		print_version $0
		;;	
	h)	
		print_usage $0
		;;
        F)
                FREE_SUBQUERY_CHECK="OK"
		FREE_SUBQUERY="$OPTARG"
		;;
	R)
                export FAILED="$OPTARG"
		export check_save_failed='OK'
		;;
	D)
		export save_products_failed='OK'
		;;
	r)
                export FAILED_retry="$OPTARG"
		export check_retry='OK'
		;;
	O)
		export output_folder="$OPTARG"
                export OUTPUT_FOLDER_IS_SET='OK'
		;;
        N)
		export number_tries="$OPTARG"
		;;
	L)
		export lock_file="$OPTARG"
                export LOCK_FILE_IS_SET='OK'
		;;
 	n)
                export THREAD_NUMBER="$OPTARG"
                export THREAD_NUMBER_IS_SET='OK'
                ;;
	esac
done
echo ""
echo "================================================================================================================" 
echo ""
echo "dhusget version: $VERSION"
echo ""
echo "USAGE: $print_script [LOGIN OPTIONS]... [SEARCH QUERY OPTIONS]... [SEARCH RESULT OPTIONS]... [DOWNLOAD OPTIONS]... "
echo ""
echo "Type '$print_script -help' for usage information"
echo ""
echo "================================================================================================================" 
ISSELECTEDEXIT=false;
trap ISSELECTEDEXIT=true INT;

if [ -z $lock_file ];then
        export lock_file="$WD/lock"
fi 

mkdir $lock_file

if [ ! $? == 0 ]; then 
	echo -e "Error! An instance of \"dhusget\" retriever is running !\n Pid is: "`cat ${PIDFILE}` "if it isn't running delete the lockdir  ${lock_file}"
	
	exit 
else
	echo $$ > $PIDFILE
fi

trap "rm -fr ${lock_file}" EXIT

export TIME_SUBQUERY="ingestiondate:[$INGEGESTION_TIME_FROM TO $INGEGESTION_TIME_TO]  "

export SENSING_SUBQUERY="beginPosition:[$SENSING_TIME_FROM TO $SENSING_TIME_TO]  "

if [ -z $THREAD_NUMBER ];then
        export THREAD_NUMBER="2"
fi

if [ -z $output_folder ];then
        export output_folder="PRODUCT"
fi

export WC="wget --no-check-certificate"

echo "LOGIN"

printf "\n"

if [ -z $DHUS_DEST_IS_SET ];then
echo "'-d option' not specified. "
echo "Default Data Hub Service URL is: "
else
echo "Specified Data Hub Service URL is:"
fi
echo $DHUS_DEST

printf "\n"

if [ ! -z $USERNAME ] && [ -z $PASSWORD ];then
echo "You have inserted only USERNAME"
echo ""
fi

if [ -z $USERNAME ] && [ ! -z $PASSWORD ];then
echo "You have inserted only PASSWORD"
echo ""
fi

if [ -z $USERNAME ];then
        read -p "Enter username: " VAL
        printf "\n"
        export USERNAME=${VAL}
fi

if [ -z $PASSWORD ];then
	read -s -p "Enter password: " VAL
        printf "\n\n"
	export PASSWORD=${VAL}
fi

export AUTH="--user=${USERNAME} --password=${PASSWORD}"

if [ -z $number_tries ];then  
      export TRIES="--tries=5"
else
      export TRIES="--tries=${number_tries}"
fi

mkdir -p './logs/'

if [ ! -z $check_retry ] && [ -s $FAILED_retry ]; then
	 cp $FAILED_retry .failed.control.retry.now.txt
   	 export INPUT_FILE=.failed.control.retry.now.txt


	mkdir -p $output_folder

if [ -f .failed.control.now.txt ]; then
    rm .failed.control.now.txt
fi
cat ${INPUT_FILE} | xargs -n 4 -P ${THREAD_NUMBER} sh -c ' while : ; do
        echo "Downloading product ${3} from link ${DHUS_DEST}/odata/v1/Products('\''"$1"'\'')/\$value"; 
        ${WC} ${AUTH} ${TRIES} --progress=dot -e dotbytes=10M -c --output-file=./logs/log.${3}.log -O $output_folder/${3}".zip" "${DHUS_DEST}/odata/v1/Products('\''"$1"'\'')/\$value";
        test=$?;
        if [ $test -eq 0 ]; then
                echo "Product ${3} successfully downloaded at " `tail -2 ./logs/log.${3}.log | head -1 | awk -F"(" '\''{print $2}'\'' | awk -F")" '\''{print $1}'\''`;
                remoteMD5=$( ${WC} -qO- ${AUTH} ${TRIES} -c "${DHUS_DEST}/odata/v1/Products('\''"$1"'\'')/Checksum/Value/$value" | awk -F">" '\''{print $3}'\'' | awk -F"<"     '\''{print $1}'\'');
                localMD5=$( openssl md5 $output_folder/${3}".zip" | awk '\''{print $2}'\'');
                localMD5Uppercase=$(echo "$localMD5" | tr '\''[:lower:]'\'' '\''[:upper:]'\'');
                if [ "$remoteMD5" == "$localMD5Uppercase" ]; then
                        echo "Product ${3} successfully MD5 checked";
                else
                echo "Checksum for product ${3} failed";
                echo "${0} ${1} ${2} ${3}" >> .failed.control.now.txt;
                if [ ! -z $save_products_failed ];then  
		      rm $output_folder/${3}".zip"
		fi
                fi; 
        else
                echo "${0} ${1} ${2} ${3}" >> .failed.control.now.txt;
                if [ ! -z $save_products_failed ];then
		      rm $output_folder/${3}".zip"
                fi
        fi;
        break;
done '
rm .failed.control.retry.now.txt
fi

#----- Options value check
echo "================================================================================================================"
echo ""
echo "SEARCH QUERY OPTIONS"
if [ -z $TIME ] && [ -z $TIMEFILE ] && [ -z $ROW ] && [ -z $PRODUCT_TYPE ] && [ -z $FREE_SUBQUERY_CHECK ] && [ -z $SENSING_TIME ] && [ -z $MISSION ] && [ -z $INSTRUMENT ];
then
     echo ""
     echo "No Search Options specified. Default query is q='*'."
     echo ""
     export QUERY_STATEMENT="*"
else
echo ""
fi
if [ -z $MISSION ]; then
	echo "'-m option' not specified. Search is performed on all available sentinel missions."
        echo ""
else
        echo "'-m option' mission is set to $MISSION. "
        echo ""
fi
if [ -z $INSTRUMENT ]; then
	echo "'-i option' not specified. Search is performed on all available instruments."
        echo ""
else
        echo "'-i option' instrument is set to $INSTRUMENT. "
        echo ""
fi
if [ -z $TIME ]; then
	echo " Ingestion date options not specified ('-t', '-s', '-e').  "
        echo ""
else
if [ ! -z $isselected_filtertime_ingestion_date ] && [ ! -z $isselected_filtertime_lasthours ]; then 
             if [ -z $TIMEFILE ];then 
		echo "'-s option' and '-e option' are set to $INGEGESTION_TIME_FROM and $INGEGESTION_TIME_TO. Search is performed for all products ingested in the period [$INGEGESTION_TIME_FROM,$INGEGESTION_TIME_TO]. "
	        echo ""
             else
                echo "'-f option' is specified. Search is performed for all products ingested in the period [$INGEGESTION_TIME_FROM,$INGEGESTION_TIME_TO]. "
	        echo ""
             fi
     else 
     if [ ! -z $isselected_filtertime_lasthours ]; then
        if [ -z $TIMEFILE ];then
         echo "'-t option' is set to $TIME. Search is performed for all products ingested in the last $TIME hours. "
         echo ""
        fi 
     else
         echo "'-s option' and '-e option' are set to $INGEGESTION_TIME_FROM and $INGEGESTION_TIME_TO. Search is performed for all products ingested in the period [$INGEGESTION_TIME_FROM,$INGEGESTION_TIME_TO]. "
         echo "" 
     fi
     fi
fi
if [ -z $SENSING_TIME ]; then
	echo " Sensing date options not specified ('-S', '-E')."
        echo ""
else
        echo "'-S option' and '-E option' are set to $SENSING_TIME_FROM and $SENSING_TIME_TO. Search for all products having sensing date included in [$SENSING_TIME_FROM,$SENSING_TIME_TO]. "
         echo ""
fi
if [ ! -z $TIMEFILE ] && [ -z $isselected_filtertime_ingestion_date ]; then
	echo "'-f option' is set to $TIMEFILE. The ingestion date provided through $TIMEFILE is used to search all products ingested in the period [DATEINGESTION,NOW]. The file is updated with the ingestion date of the last available product found. "
        echo ""
fi
if [ -z $ROW ]; then
	echo "'-c option' not specified. No specified Area of Interest. Search is performed on the whole globe."
        echo ""
else
        echo "'-c option' is set to $x1,$y1:$x2,$y2. Search is performed on an Area of interest defined as a bounding box delimited by the two opposite vertices P1=[lon1=$x1,lat1=$y1] and P2=[lon2=$x2,lat2=$y2]. "
        echo ""
fi
if [ -z $PRODUCT_TYPE ]; then
	echo "'-T option' not specified. Search is performed on all available product types. "
        echo ""
else
        echo "'-T option' product type is set to $PRODUCT_TYPE. "
        echo ""
fi
if [ ! -z $FREE_SUBQUERY_CHECK ]; then
        echo "'-F option' is set to $FREE_SUBQUERY. This OpenSearch query will be in AND with other search options. "
        echo ""
fi
echo "SEARCH RESULT OPTIONS"
echo ""
if [ -z $ROWS ]; then
	echo "'-l option' not specified. Default Maximum Number of Results per page is 25. "
        echo ""
else
        echo "'-l option' is set to $ROWS. The number of results per page is $ROWS. "
        echo ""
fi
if  [ -z $PAGE ]; then
	echo "'-P option' not specified. Default Page Number is 1. "
        echo ""
else
        echo "'-P option' is set to $PAGE. The page visualized is $PAGE. "
        echo ""
fi
if [ -z $NAMEFILERESULTS ]; then
	echo "'-q option' not specified. OpenSearch results are stored by default in ./OSquery-result.xml. "
        echo ""
else
        echo "'-q option' is set to $NAMEFILERESULTS. OpenSearch results are stored in $NAMEFILERESULTS. "
        echo ""
fi
if [ -z $PRODUCTLIST ]; then
	echo "'-C option' not specified. List of results are stored by default in the CSV file ./products-list.csv. "
        echo ""
else
        echo "'-C option' is set to $PRODUCTLIST. List of results are stored in the specified CSV file $PRODUCTLIST. "
        echo ""
fi
if [ ! -z $TO_DOWNLOAD ] || [ ! -z $check_retry ];then
CHECK_VAR=true;
else
CHECK_VAR=false;
fi
echo "DOWNLOAD OPTIONS"
echo ""
if [ $CHECK_VAR == false ];then
echo "No download options specified. No files will be downloaded. "
echo ""
fi
if [ ! -z $TO_DOWNLOAD ]; then
        if [ $TO_DOWNLOAD=="product" ]; then
            echo "'-o option' is set to $TO_DOWNLOAD. Downloads are active. By default product downloads are stored in ./PRODUCT unless differently specified by the '-O option'. "
            echo ""
        else 
        if [ $TO_DOWNLOAD=="manifest" ]; then
            echo "'-o option' is set to $TO_DOWNLOAD. Only manifest files are downloaded. Manifest files are stored in ./manifest. "
            echo ""
        else
            echo "'-o option' is set to $TO_DOWNLOAD. Downloads are active. Products and manifest files are downloded separately. "
            echo ""
        fi
        fi
fi

if [[ $CHECK_VAR == true &&  ! -z $OUTPUT_FOLDER_IS_SET ]]; then
    echo "'-O option' is set to $output_folder. Product downloads are stored in ./$output_folder. "
    echo ""
fi
if [[ $CHECK_VAR == true  &&  -z $number_tries ]]; then
        echo "'-N option' not specified. By default the number of wget download retries is 5. "
        echo "" 
else
   if [[ $CHECK_VAR == true  &&  ! -z $number_tries ]]; then
        echo "'-N option' is set to $number_tries. The number of wget download retries is $number_tries. "
        echo ""
   fi
fi
if [[ $CHECK_VAR == true  &&  -z $check_save_failed ]]; then
        echo "'-R option' not specified. By default the list of products failing the MD5 integrity check is saved in ./failed_MD5_check_list.txt. "
        echo "" 
else
     if [[ $CHECK_VAR == true  &&  ! -z $check_save_failed ]]; then
        echo "'-R option' is set to $FAILED. The list of products failing the MD5 integrity check is saved in $FAILED. "
        echo ""
     fi
fi
if [[ $CHECK_VAR == true  &&  ! -z $save_products_failed ]]; then
    echo "'-D option' is active. Products that have failed the MD5 integrity check are deleted from the local disks. "
    echo ""
fi
if [[ $CHECK_VAR == true  &&  ! -z $check_retry ]]; then
    echo "'-r option' is set to $FAILED_retry. It retries the download of the products listed in $FAILED_retry. "
    echo ""
fi
if [ ! -z $LOCK_FILE_IS_SET ]; then
        echo "'-L option' is set to $lock_file. This instance of dhusget can be executed in parallel to other instances. "
        echo ""
fi
if [[ $CHECK_VAR == true  &&  -z $THREAD_NUMBER_IS_SET ]]; then
        echo "'-n option' not specified. By default the number of concurrent downloads (either products or manifest files) is 2. "
        echo ""
else
    if [[ $CHECK_VAR == true  &&  ! -z $THREAD_NUMBER_IS_SET ]]; then
        echo "'-n option' is set to $THREAD_NUMBER. The number of concurrent downloads (either products or manifest files) is set to $THREAD_NUMBER. Attention, this value doesn't override the quota limit set on the server side for the user. "
        echo ""
    fi
fi
echo "================================================================================================================"
echo ""
if [ ! -z $MISSION ];then
	if [ ! -z $QUERY_STATEMENT_CHECK ]; then
		export QUERY_STATEMENT="$QUERY_STATEMENT AND "	
	fi
	export QUERY_STATEMENT="$QUERY_STATEMENT platformname:$MISSION"
	QUERY_STATEMENT_CHECK='OK'	
fi 
if [ ! -z $INSTRUMENT ];then
	if [ ! -z $QUERY_STATEMENT_CHECK ]; then
		export QUERY_STATEMENT="$QUERY_STATEMENT AND "	
	fi
	export QUERY_STATEMENT="$QUERY_STATEMENT instrumentshortname:$INSTRUMENT"
	QUERY_STATEMENT_CHECK='OK'	
fi 
if [ ! -z $PRODUCT_TYPE ];then
	if [ ! -z $QUERY_STATEMENT_CHECK ]; then
		export QUERY_STATEMENT="$QUERY_STATEMENT AND "	
	fi
	export QUERY_STATEMENT="$QUERY_STATEMENT producttype:$PRODUCT_TYPE"
	QUERY_STATEMENT_CHECK='OK'	
fi 
if [ ! -z $TIME ];then
	if [ ! -z $QUERY_STATEMENT_CHECK ]; then
		export QUERY_STATEMENT="$QUERY_STATEMENT AND "	
	fi
	export QUERY_STATEMENT="$QUERY_STATEMENT ${TIME_SUBQUERY}"
	QUERY_STATEMENT_CHECK='OK'
fi

if [ ! -z $SENSING_TIME ];then
        if [ ! -z $QUERY_STATEMENT_CHECK ]; then
                export QUERY_STATEMENT="$QUERY_STATEMENT AND "
        fi
        export QUERY_STATEMENT="$QUERY_STATEMENT ${SENSING_SUBQUERY}"
	QUERY_STATEMENT_CHECK='OK'
fi

if [ ! -z $TIMEFILE ];then
        if [ ! -z $QUERY_STATEMENT_CHECK ]; then
                export QUERY_STATEMENT="$QUERY_STATEMENT AND "
        fi
        export QUERY_STATEMENT="$QUERY_STATEMENT ${TIME_SUBQUERY}"

	QUERY_STATEMENT_CHECK='OK'
fi

if [ ! -z $FREE_SUBQUERY_CHECK ];then
        if [ ! -z $QUERY_STATEMENT_CHECK ]; then
                export QUERY_STATEMENT="$QUERY_STATEMENT AND "
        fi
        export QUERY_STATEMENT="$QUERY_STATEMENT $FREE_SUBQUERY"
	QUERY_STATEMENT_CHECK='OK'
fi

#---- Prepare query polygon statement
if [ ! -z $x1 ];then
	if [[ ! -z $QUERY_STATEMENT ]]; then
		export QUERY_STATEMENT="$QUERY_STATEMENT AND "	
	fi
	export GEO_SUBQUERY=`LC_NUMERIC=en_US.UTF-8; printf "( footprint:\"Intersects(POLYGON((%.13f %.13f,%.13f %.13f,%.13f %.13f,%.13f %.13f,%.13f %.13f )))\")" $x1 $y1 $x2 $y1 $x2 $y2 $x1 $y2 $x1 $y1 `
	export QUERY_STATEMENT=${QUERY_STATEMENT}" ${GEO_SUBQUERY}"
else
	export GEO_SUBQUERY=""
fi
#- ... append on query (without repl
if [ -z $ROWS ];then
        export ROWS=25
fi

if [ -z $PAGE ];then
        export PAGE=1
fi
START=$((PAGE-1))
START=$((START*ROWS))
export QUERY_STATEMENT="${DHUS_DEST}/search?q="${QUERY_STATEMENT}"&rows="${ROWS}"&start="${START}""
echo "HTTP request done: "$QUERY_STATEMENT""
echo ""
#--- Execute query statement
if [ -z $NAMEFILERESULTS ];then
        export NAMEFILERESULTS="OSquery-result.xml"
fi
/bin/rm -f $NAMEFILERESULTS
${WC} ${AUTH} ${TRIES} -c -O "${NAMEFILERESULTS}" "${QUERY_STATEMENT}"
LASTDATE=`date -u +%Y-%m-%dT%H:%M:%S.%NZ`
sleep 5

cat $PWD/"${NAMEFILERESULTS}" | grep '<id>' | tail -n +2 | cut -f2 -d'>' | cut -f1 -d'<' | cat -n > .product_id_list

cat $PWD/"${NAMEFILERESULTS}" | grep '<link rel="alternative" href=' | cut -f4 -d'"' | cat -n | sed 's/\/$//'> .product_link_list

cat $PWD/"${NAMEFILERESULTS}" | grep '<title>' | tail -n +2 | cut -f2 -d'>' | cut -f1 -d'<' | cat -n > .product_title_list
if [ ! -z $TIMEFILE ];then
if [ `cat "${NAMEFILERESULTS}" | grep '="ingestiondate"' |  head -n 1 | cut -f2 -d'>' | cut -f1 -d'<' | wc -l` -ne 0 ];
then
	lastdate=`cat $PWD/"${NAMEFILERESULTS}" | grep '="ingestiondate"' |  head -n 1 | cut -f2 -d'>' | cut -f1 -d'<'`;
	years=`echo $lastdate | tr "T" '\n'|head -n 1`;
	hours=`echo $lastdate | tr "T" '\n'|tail -n 1`;
	echo `date +%Y-%m-%d --date="$years"`"T"`date +%T.%NZ -u --date="$hours + 0.001 seconds"`> $TIMEFILE
fi 
fi

paste -d\\n .product_id_list .product_title_list | sed 's/[",:]/ /g' > product_list

cat .product_title_list .product_link_list | sort -k1n,1 -k2r,2 | sed 's/[",:]/ /g' | sed 's/https \/\//https:\/\//' > .product_list_withlink

rm -f .product_id_list .product_link_list .product_title_list .product_ingestion_time_list

echo ""

cat "${NAMEFILERESULTS}" | grep '<subtitle>' | cut -f2 -d'>' | cut -f1 -d'<' | cat -n

NPRODUCT=`cat "${NAMEFILERESULTS}" | grep '<subtitle>' | cut -f2 -d'>' | cut -f1 -d'<' | cat -n | cut -f11 -d' '`;
 
echo ""

if [ "${NPRODUCT}" == "0" ]; then exit 1; fi

cat .product_list_withlink
if [ -z $PRODUCTLIST ];then
   export PRODUCTLIST="products-list.csv"
fi
cp .product_list_withlink $PRODUCTLIST
cat $PRODUCTLIST | cut -f2 -d$'\t' > .products-list-tmp.csv
cat .products-list-tmp.csv | grep -v 'https' > .list_name_products.csv
cat .products-list-tmp.csv | grep 'https' > .list_link_to_products.csv
paste -d',' .list_name_products.csv .list_link_to_products.csv > $PRODUCTLIST 
rm .product_list_withlink .products-list-tmp.csv .list_name_products.csv .list_link_to_products.csv  
export rv=0
if [ "${TO_DOWNLOAD}" == "manifest" -o "${TO_DOWNLOAD}" == "all" ]; then
	export INPUT_FILE=product_list

	if [ ! -f ${INPUT_FILE} ]; then
	 echo "Error: Input file ${INPUT_FILE} not present "
	 exit
	fi

	mkdir -p MANIFEST/

cat ${INPUT_FILE} | xargs -n 4 -P ${THREAD_NUMBER} sh -c 'while : ; do
	echo "Downloading manifest ${3} from link ${DHUS_DEST}/odata/v1/Products('\''"$1"'\'')/Nodes('\''"$3".SAFE'\'')/Nodes('\'manifest.safe\'')/\$value"; 
	${WC} ${AUTH} ${TRIES} --progress=dot -e dotbytes=10M -c --output-file=./logs/log.${3}.log -O ./MANIFEST/manifest.safe-${3} "${DHUS_DEST}/odata/v1/Products('\''"$1"'\'')/Nodes('\''"$3".SAFE'\'')/Nodes('\'manifest.safe\'')/\$value" ;
	test=$?;
	if [ $test -eq 0 ]; then
		echo "Manifest ${3} successfully downloaded at " `tail -2 ./logs/log.${3}.log | head -1 | awk -F"(" '\''{print $2}'\'' | awk -F")" '\''{print $1}'\''`;
	fi;
	[[ $test -ne 0 ]] || break;
done ' 
fi

if [ "${TO_DOWNLOAD}" == "product" -o "${TO_DOWNLOAD}" == "all" ];then

    export INPUT_FILE=product_list


mkdir -p $output_folder

#Xargs works here as a thread pool, it launches a download for each thread (P 2), each single thread checks 
#if the download is completed succesfully.
#The condition "[[ $? -ne 0 ]] || break" checks the first operand, if it is satisfied the break is skipped, instead if it fails 
#(download completed succesfully (?$=0 )) the break in the OR is executed exiting from the intitial "while".
#At this point the current thread is released and another one is launched.
if [ -f .failed.control.now.txt ]; then
    rm .failed.control.now.txt
fi
cat ${INPUT_FILE} | xargs -n 4 -P ${THREAD_NUMBER} sh -c ' while : ; do
	echo "Downloading product ${3} from link ${DHUS_DEST}/odata/v1/Products('\''"$1"'\'')/\$value"; 
        ${WC} ${AUTH} ${TRIES} --progress=dot -e dotbytes=10M -c --output-file=./logs/log.${3}.log -O $output_folder/${3}".zip" "${DHUS_DEST}/odata/v1/Products('\''"$1"'\'')/\$value";
	test=$?;
	if [ $test -eq 0 ]; then
		echo "Product ${3} successfully downloaded at " `tail -2 ./logs/log.${3}.log | head -1 | awk -F"(" '\''{print $2}'\'' | awk -F")" '\''{print $1}'\''`;
		remoteMD5=$( ${WC} -qO- ${AUTH} ${TRIES} -c "${DHUS_DEST}/odata/v1/Products('\''"$1"'\'')/Checksum/Value/$value" | awk -F">" '\''{print $3}'\'' | awk -F"<" '\''{print $1}'\'');
		localMD5=$( openssl md5 $output_folder/${3}".zip" | awk '\''{print $2}'\'');
		localMD5Uppercase=$(echo "$localMD5" | tr '\''[:lower:]'\'' '\''[:upper:]'\'');
		#localMD5Uppercase=1;
		if [ "$remoteMD5" == "$localMD5Uppercase" ]; then
			echo "Product ${3} successfully MD5 checked";
		else
		echo "Checksum for product ${3} failed";
		echo "${0} ${1} ${2} ${3}" >> .failed.control.now.txt;
		if [ ! -z $save_products_failed ];then  
		      rm $output_folder/${3}".zip"
		fi
		fi; 
	else
                echo "${0} ${1} ${2} ${3}" >> .failed.control.now.txt;
                if [ ! -z $save_products_failed ];then  
		      rm $output_folder/${3}".zip"
                fi
	fi;
        break;
done '
fi
if [ ! -z $check_save_failed ]; then
    if [ -f .failed.control.now.txt ];then
    	mv .failed.control.now.txt $FAILED
    else 
    if [ ! -f .failed.control.now.txt ] && [ $CHECK_VAR == true ] && [ ! ISSELECTEDEXIT ];then
    	echo "All downloaded products have successfully passed MD5 integrity check"
    fi
    fi
else
    if [ -f .failed.control.now.txt ];then
    	 mv .failed.control.now.txt failed_MD5_check_list.txt
    else 
    if [ ! -f .failed.control.now.txt ] && [ $CHECK_VAR == true ] && [ ! ISSELECTEDEXIT ];then
    	echo "All downloaded products have successfully passed MD5 integrity check"
    fi
    fi
fi
echo 'the end'
