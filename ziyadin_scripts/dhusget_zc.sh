#!/bin/bash 
#----------------------------------------------------------------------------------------#
# Demo script illustrating some examples using the OData interface                       #
# of the Data Hub Service (DHuS)                                                         #
#----------------------------------------------------------------------------------------#
# Serco SpA 2014                                                                         # 
# Ziyadin Cakir, 2015, -z option for an acqusition period                                #
# Ziyadin Cakir, 2016, -s option for product sensing mode                                #         
# Ziyadin Cakir, 2016, -k option choosing acqusition time                                # 
# Ziyadin Cakir, 2016, -c flag for wget to resume                                        # 
# Ziyadin Cakir, 2016, -j relative orbit number                                          # 
# Ziyadin Cakir, 2016, -v path for download directory                                    #
# Ziyadin Cakir, 2016, download each to its own track folder under given path or to $CWD # 
#----------------------------------------------------------------------------------------#
export VERSION=0.1

WD=$HOME/.dhusget
PIDFILE=$WD/pid
LOCK=$WD/lock
#LOCK=`\ls -d $WD/lock* | wc -l`  


test -d $WD || mkdir -p $WD 

#-
#np=2
#if [ $LOCK -lt $np ]; then
# mkdir -p $WD/lock$$
#fi

if [ ! $? == 0 ]; then 
#if [ ${LOCK} == $np ]; then
	echo -e "Error! two istances of \"dhusget\" retriever is running !\n Pid is: "`cat ${PIDFILE}` "if it isn't running delete the lockdir  ${LOCK}"
	exit 
else
	echo $$ > $PIDFILE
fi

trap "rm -fr ${LOCK}$$" EXIT

#trap "rm -fr  $WD/lock$$" EXIT

function print_usage 
{ 
 echo " "
 echo "---------------------------------------------------------------------------------------------------------------------------"
 echo " "
 echo "This is dhusget $VERSION, a non interactive Sentinel-1 product (or manifest) retriever from a Data Hub instance."
 echo " " 
 echo "Usage: $1 [-d <DHuS URL>] [-u <username> ] [ -p <password>] [-t <time to search (hours)>] -z <time priod for images ie:2015-01-01:2015-12-30> [-c <coordinates ie: x1,y1;x2,y2>] [-T <product type>] [-o <option>] [-z <acquisiton period>] [-s <sensing mod>] [-k <time>] [-j <relative orbit number>]"
 echo " "
 echo "---------------------------------------------------------------------------------------------------------------------------"
 echo " "
 echo "-u <username>         : data hub username provided after registration on <DHuS URL> ;"
 echo "-p <password>         : data hub password provided after registration on <DHuS URL> , (note: it's read from stdin, if isn't provided by commandline);"
 echo " "
 echo "-t <sensing date from >      : beginning date for search , e.g. 2016-01-01 ;"
 echo ""
 echo " -f <file>                       : A file containg the time of last successfully download"
 echo " "
 echo "-c <coordinates ie:                lon1,lat1,:lon2,lat2> : coordinates of two opposite vertices of the rectangular area of interest ; "
 echo " "
 echo "-T <product type>                : product type of the product to search (available values are:  SLC, GRD, OCN and RAW) ;"
 echo " "
 echo "-o <option>                      : what to download, possible options are:"
 echo "                                   - 'manifest' to download the manifest of all products returned from the search or "
 echo "                                   - 'product' to download all products returned from the search "
 echo "                                   - 'all' to download both."
 echo "                                		N.B.: if this parameter is left blank, the dhusget will return the UUID and the names "
 echo " 			      					 of the products found in the DHuS archive."
 echo " -z <acquisiton period>               : Give the begining and ending dates for products as YYYY-MM-DD:YYYY-MM-DD"
 echo " -s <sensing mode>                    :IW, SM or EW" 
 echo " -j <relative orbit number>           : give relative orbit number"
 echo " -k <acquisition time>                : begining  time for image acquistion as hh:mm:ss and before (b) or after(a) flag;e.g. 15:30:40:b" 
 echo " -v <download directory >             : give path to download directory. e.g., ./istanbul Track folders will be created under this directory "
 echo "  'wget' is necessary to run the dhusget"
 echo " " 

 exit -1
}

#----------------------
#---  Load input parameter
export DHUS_DEST="https://dhus.example.com"
export USERNAME="test"
#export PASSWORD="test"
export TIME_SUBQUERY=""
export PRODUCT_TYPE='*'
export SENSINGMODE=""
unset TIMEFILE
while getopts ":d:u:p:t:f:c:T:o:z:s:k:j:v:" opt; do
 case $opt in
	d)
		export DHUS_DEST="$OPTARG"
		;;
	u)
		export USERNAME="$OPTARG"
		;;
	p)
		export PASSWORD="$OPTARG"
		;;
	t)
		export TIME="$OPTARG"
		export TIME_SUBQUERY="beginPosition:[${TIME}T00:00:00.000Z TO NOW] "
		;;	
	f)
		export TIMEFILE="$OPTARG"
		if [ -f $TIMEFILE ]; then 		
			export TIME_SUBQUERY="ingestiondate:[`cat $TIMEFILE` TO NOW] AND "
		else
			export TIME_SUBQUERY="ingestiondate:[1970-01-01T00:00:00.000Z TO NOW] AND "
		fi
		;;
	c) 
		ROW="$OPTARG"

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
        z)
		export TIME="$OPTARG"
		Df=`echo "$TIME" | awk -F\: '{print \$1}' `
		Dl=`echo "$TIME" | awk -F\: '{print \$2}' `		
		export TIME_SUBQUERY="beginPosition:[${Df}T00:00:00.000Z TO ${Dl}T23:59:59.999Z] AND endPosition:[${Df}T00:00:00.000Z TO ${Dl}T23:59:59.999Z]"
		;;
        s) export SENSINGMODE="$OPTARG"
         ;;	

        k) export TLIM="$OPTARG"
          SAAT=`echo $TLIM | awk -F: '{print $1":"$2":"$3}'`
          TFL=`echo $TLIM | awk -F: '{print $4}'`
           ;;	
        j) export TRACK="$OPTARG"
         ;;
        v) 
          export DIR="$OPTARG"
        ;; 	
	*)	
         print_usage $0
	 ;;
				
	 esac
done

if [ -z $PASSWORD ];then
	read -s -p "Enter password ..." VAL
	export PASSWORD=${VAL}
fi

#-----
export WC="wget --no-check-certificate -c"
#--ca-certificate=/etc/pki/CA/certs/ca.cert.pem"
export AUTH="--user=${USERNAME} --password=${PASSWORD}"


#--- Prepare query statement

#export QUERY_STATEMENT="${DHUS_DEST}/search?q=ingestiondate:[NOW-${TIME}DAYS TO NOW] AND producttype:${PRODUCT_TYPE}"
if [ "${TIME}" == ""  ]; then
export QUERY_STATEMENT="${DHUS_DEST}/search?q= producttype:${PRODUCT_TYPE} AND sensorOperationalMode:${SENSINGMODE} AND platformname:Sentinel-1"
else
export QUERY_STATEMENT="${DHUS_DEST}/search?q=${TIME_SUBQUERY} AND producttype:${PRODUCT_TYPE} AND sensorOperationalMode:${SENSINGMODE} AND platformname:Sentinel-1"
fi

if [ ! -z ${TRACK} ]; then
export QUERY_STATEMENT="${QUERY_STATEMENT}  AND relativeorbitnumber:${TRACK} "
fi

#echo $TRACK

#--- 
#export QUERY_STATEMENT=`echo "${QUERY_STATEMENT}"|sed 's/ /+/g'`

#---- Prepare query polygon statement
if [ ! -z $x1 ];then
	export GEO_SUBQUERY=`LC_NUMERIC=en_US.UTF-8; printf " ( footprint:\"Intersects(POLYGON((%.13f %.13f,%.13f %.13f,%.13f %.13f,%.13f %.13f,%.13f %.13f )))\")" $x1 $y1 $x2 $y1 $x2 $y2 $x1 $y2 $x1 $y1 `
else
	export GEO_SUBQUERY=""
fi

#- ... append on query (without repl)
# export QUERY_STATEMENT=${QUERY_STATEMENT}" AND ${GEO_SUBQUERY}&rows=10000&start=0"
export QUERY_STATEMENT=${QUERY_STATEMENT}" AND ${GEO_SUBQUERY}&rows=100&start=0"

export QUERY_STATEMENT=${QUERY_STATEMENT}

#--- Select output format
#export QUERY_STATEMENT+="&format=json"
echo ""
echo ""
echo $QUERY_STATEMENT
#--- Execute query statement
/bin/rm -f query-result
mkdir -p ./output/
set -x
${WC} ${AUTH} --output-file=./output/.log_query.log -O query-result -c "${QUERY_STATEMENT}"
set +x
LASTDATE=`date -u +%Y-%m-%dT%H:%M:%S.%NZ`
#sleep 5

if [ ! -z ${TRACK} ]; then
 product_list=${TRACK}_product_list
else
 product_list=`whoami`_product_list
fi 
echo ""

cat $PWD/query-result | grep '<id>' | awk 'NF == 1 {print $0}' | cut -f2 -d'>' | cut -f1 -d'<' | cat -n > .product_id_list
cat $PWD/query-result | grep '"identifier"'  | cut -f2 -d'>' | cut -f1 -d'<' | cat -n > .product_title_list
cat $PWD/query-result | grep lastrelativeorbitnumber | cut -f2 -d'>' | cut -f1 -d'<' | cat -n > .product_track_list
#paste .product_track_list .product_id_list .product_title_list  | awk '{print $1, $2;print $1,$4;print $1,$6}' | sed 's/[",:]/ /g' > $product_list
# revers the order
paste .product_track_list .product_id_list .product_title_list | awk '{a[i++]=$0} END {for (j=i-1; j>=0;) print a[j--] }' | awk '{print NR, $2;print NR,$4;print NR,$6}' | sed 's/[",:]/ /g' > $product_list



echo ""
echo ""

#cat $product_list
export rv=0
if [ "${TO_DOWNLOAD}" == "manifest" ]; then
	#if [ -z $9 ] ; then
	export INPUT_FILE=$product_list
#	else
	#export INPUT_FILE=$9
#	fi
	if [ ! -f ${INPUT_FILE} ]; then
	 echo "Error: Input file ${INPUT_FILE} not present "
	 exit
	fi
        awk '$2 ~/S1/ {print $2}' $product_list 
        NROW=`cat $product_list |wc -l`
        NPRODUCT=`echo ${NROW}/3 | bc -q `
         echo ""
        echo -e "search contains ${NPRODUCT} products "
        awk '{a[$2]++} END {for (i in a) print a[i], "in T" i}' .product_track_list
       nim=0 
	while read -r  line ; do 
         track=`echo $line | awk '{print $2}'`
         #
 	 read line 
	 UUID=`echo $line | awk '{print $2}'`
	 read line 
	 PRODUCT_NAME=`echo $line | awk '{print $2}'`
         if [ ! -z $DIR ]; then
          if [ -e $DIR ]; then
           n=`find ./$DIR -name $PRODUCT_NAME`
           if [ ! -z "$n" ]; then
            nim=`expr $nim + 1`
           fi
          else
           #mkdir $DIR
           DDIR=$DIR/T$track 
          fi
         else
          #
          if [ -e "T$track" ]; then  
           n=`find ./T$track -name $PRODUCT_NAME`
           if [ ! -z "$n" ]; then
            nim=`expr $nim + 1`
           fi
          else
           #mkdir T$track
           DDIR=T$track  
           #echo $DDIR        
          fi
         fi 
        done < $product_list
        echo -e " "
        echo -e "of these, $nim seem to be already donloaded (those that are partially downloaded will be resumed) " 
        echo -e " "
        echo "remaining `expr ${NPRODUCT} - ${nim}` images will be downloaded" 

  if [ -z $SAAT ];then
    NROW=`cat $product_list |wc -l`
    NPRODUCT=`echo ${NROW}/3 | bc -q `
   # echo "no time is given,  all will be downloaded"
    echo ""
    echo ""
  else
     if [ -e filtered_$product_list ] ;then 
     \rm filtered_$product_list
     fi 
     touch filtered_$product_list
     \cp $product_list $product_list_back
     i=0
     if [ "${TFL}" = "a" ]; then
     for line in `awk -F_ -v t=${SAAT} '{h1=substr($6,10,2);m1=substr($6,12,2);s1=substr($6,14,2);tt1=h1*3600*+m1*60+s1; h2=substr(t,1,2);m2=substr(t,4,2);s2=substr(t,7,2);tt2=h2*3600*+m2*60+s2;  if (tt1 > tt2) print NR-1,NR}' $product_list`; do
      arr[$i]=$line
      n=${arr[$i]}
      awk '{if(NR=='$n') print $0}' $product_list >> filtered_$product_list 
     done
    elif [ "${TFL}" = "b" ]; then
     for line in `awk -F_ -v t=${SAAT} '{h1=substr($6,10,2);m1=substr($6,12,2);s1=substr($6,14,2);tt1=h1*3600*+m1*60+s1; h2=substr(t,1,2);m2=substr(t,4,2);s2=substr(t,7,2);tt2=h2*3600*+m2*60+s2;  if (tt1 > 0 && tt1 < tt2) print NR-1,NR}' $product_list`; do
     arr[$i]=$line
     n=${arr[$i]}
      awk '{if(NR=='$n') print $0}' $product_list >> filtered_$product_list  
     done
    else 
     echo -e " time flag is wrong"
     exit
    fi
    \cp filtered_$product_list $product_list
    NROW=`cat $product_list |wc -l`
    NPRODUCT=`echo ${NROW}/3 | bc -q `
    NROWF=`cat filtered_$product_list |wc -l`
    NPRODUCTF=`echo ${NROWF}/3 | bc -q `
    echo ""
    echo ""
    if [ "${TFL}" = "a" ]; then
     echo -e "of these ${NPRODUCTF} acquired after ${SAAT} will be downloaded"
     echo ""
    else 
     echo -e "of these ${NPRODUCTF} acquired before ${SAAT} will be downloaded"
     echo ""
    fi
  fi
fi




###
if [ "${TO_DOWNLOAD}" == "product" -o "${TO_DOWNLOAD}" == "all" ];then
#	if [ -z $9 ] ; then
        export INPUT_FILE=$product_list
#        else
#        export INPUT_FILE=$9
#        fi
       
  if [ -z $SAAT ];then
    NROW=`cat $product_list |wc -l`
    NPRODUCT=`echo ${NROW}/3 | bc -q `
    #echo "no precise acquision time is given,  all will be downloaded"
    echo ""
    echo ""
  else
     if [ -e filtered_$product_list ] ;then 
     \rm filtered_$product_list
     fi 
     touch filtered_$product_list
     \cp $product_list $product_list_back
     i=0
     if [ "${TFL}" = "a" ]; then
     for line in `awk -F_ -v t=${SAAT} '{h1=substr($6,10,2);m1=substr($6,12,2);s1=substr($6,14,2);tt1=h1*3600*+m1*60+s1; h2=substr(t,1,2);m2=substr(t,4,2);s2=substr(t,7,2);tt2=h2*3600*+m2*60+s2;  if (tt1 > tt2) print NR-1,NR}' $product_list`; do
      arr[$i]=$line
      n=${arr[$i]}
      awk '{if(NR=='$n') print $0}' $product_list >> filtered_$product_list 
     done
    elif [ "${TFL}" = "b" ]; then
     for line in `awk -F_ -v t=${SAAT} '{h1=substr($6,10,2);m1=substr($6,12,2);s1=substr($6,14,2);tt1=h1*3600*+m1*60+s1; h2=substr(t,1,2);m2=substr(t,4,2);s2=substr(t,7,2);tt2=h2*3600*+m2*60+s2;  if (tt1 > 0 && tt1 < tt2) print NR-1,NR}' $product_list`; do
     arr[$i]=$line
     n=${arr[$i]}
      awk '{if(NR=='$n') print $0}' $product_list >> filtered_$product_list  
     done
    else 
     echo -e " time flag is wrong"
     exit
    fi
    \cp filtered_$product_list $product_list
    NROW=`cat $product_list |wc -l`
    NPRODUCT=`echo ${NROW}/3 | bc -q `
    NROWF=`cat filtered_$product_list |wc -l`
    NPRODUCTF=`echo ${NROWF}/3 | bc -q `
    echo ""
    echo ""
    if [ "${TFL}" = "a" ]; then
     echo -e "of these ${NPRODUCTF} acquired after ${SAAT} will be downloaded"
     echo ""
    else 
     echo -e "of these ${NPRODUCTF} acquired before ${SAAT} will be downloaded"
     echo ""
    fi
  fi
        awk '$2 ~/S1/ {print $2}' $product_list 
        NROW=`cat $product_list |wc -l`
        NPRODUCT=`echo ${NROW}/3 | bc -q `
        echo ""
        echo -e "search contains ${NPRODUCT} products "
        awk '{a[$2]++} END {for (i in a) print a[i], "in T" i}' .product_track_list
         nim=0 
	while read -r  line ; do 
         track=`echo $line | awk '{print $2}'`
 	 read line 
	 UUID=`echo $line | awk '{print $2}'`
	 read line 
	 PRODUCT_NAME=`echo $line | awk '{print $2}'`
         if [ ! -z $DIR ]; then
          if [ -e $DIR ]; then
           n=`find ./$DIR -name $PRODUCT_NAME`
           if [ ! -z $n ]; then
            nim=`expr $nim + 1`
           fi
          fi
         else
          if [ -e "T$track" ]; then  
           n=`find ./T$track -name $PRODUCT_NAME`
           if [ ! -z $n ]; then
            nim=`expr $nim + 1`
           fi
          fi
         fi 
        done < $product_list
        echo -e " "
        echo -e "of these, $nim seem to be already donloaded (those that are partially downloaded will be resumed)"  
        echo "remaining `expr ${NPRODUCT} - ${nim}` images will be downloaded" 



	#--- Parsing input file
	while read -r  line ; do 
         track=`echo $line | awk '{print $2}'`
 	 read line 
	 UUID=`echo $line | awk '{print $2}'`
	 read line 
	 PRODUCT_NAME=`echo $line | awk '{print $2}'`
         if [ ! -z $DIR ]; then
           DDIR=$DIR/T$track 
          if [ ! -e $DIR/T$track ]; then
            mkdir -p $DIR/T$track
          fi
         else
          DDIR=T$track  
          if [ ! -e "T$track" ]; then  
            mkdir T$track
          fi
         fi 

        echo -e "downloading ${PRODUCT_NAME}" to $DDIR
 	${WC} ${AUTH} --output-file=./output/.log.${PRODUCT_NAME}.log -O ./$DDIR/${PRODUCT_NAME} "${DHUS_DEST}/odata/v1/Products('${UUID}')/\$value"
	r=$?
	let rv=$rv+$r
#	set +x
	done < $product_list
fi

if [ $rv == 0 ]; then
	if [ ! -z $TIMEFILE ]; then
		echo "$LASTDATE" > $TIMEFILE
	fi
fi
	

echo ""
echo ""
echo ""
echo ""




