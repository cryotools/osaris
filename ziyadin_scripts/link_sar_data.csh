#!/bin/csh  -f
#
# Script for multi SAR image processing with GMT5SAR and SBAS inversion
#
# Ziyadin Cakir, March 2016

if ($#argv < 1 ) then
echo ""
echo ""
echo " give a config_file"
echo ""
echo " ex:$0 config.sa1.gmtsar "
echo ""
echo ""
echo " setting path to data:"
echo " File names are no uniq  name for  ERS, RADARSAT2  or TSX data"
echo " So the path should contain each image in a separate folder like below with correct date"
echo ""
echo " For ERS:"
echo " ER02_SAR_IM__0P_20050606T080210_20050606T080227_DPA_52952_0000.CEOS"
echo " For RADARSAT2:"
echo " RS2_OK43873_PK423873_DK374693_FQ16_20110515_161531_HH_VV_HV_VH_SLC"
echo " For TSX"
echo " unzip all the data inside the data folder"
echo ""
echo " For CSK, TSX, ENVISAT, ALOS, ALOS2 and SENTINEL "
echo " File names are uniq. So data files can be put inside separate folders or in a single folder"
echo ""
exit 1
endif
set config_file = config_sinop_asc.gmtsar
set config_file = $1
if ( ! -e $config_file) then
 echo ""
 echo "$config_file does not exist\!\!"
 echo ""
 exit 1
endif

# set the senor; ENVISAT SENTINEL TSX ALOS1 ALOS2 ERS CSK
set sensor = `grep "sensor = " $config_file| awk '$1 !~/#/ {if ($2 = "=" && $1 == "sensor") print $0}'  | awk 'END {print $3}' `
# data format, ersdac
set format = `grep "format = " $config_file| awk '$1 !~/#/ {if ($2 = "="&& $1 == "format") print $0}'  | awk 'END {print $3}' `
# data level, slc or raw
set level = `grep "level = " $config_file| awk '$1 !~/#/ {if ($2 = "=" && $1 == "level") print $0}'  | awk 'END {print $3}' `

set data = `grep "data = " $config_file| awk '$1 !~/#/ {if ($2 = "=" && $1 == "data") print $0}'  | awk 'END {print $3}' `
# set full path to the working directory 
set workdir = `grep "workdir = " $config_file| awk '$1 !~/#/ {if ($2 = "=" && $1 == "workdir") print $0}' | awk ' END {print $3}'`; 
# name of the working directory; usually track number, region etc

 if ($data == "") then
  echo ""
  echo "  ERROR set data path"
  echo ""
  exit 1
 endif
if ($workdir == "") then
 echo ""
 echo " ERROR  set workdir path"
 echo ""
 exit 1
endif
 if ($sensor == "") then
  echo ""
  echo " ERROR  set sensor type"
  echo ""
  exit 1
 endif
# make sure sensor is set correctly
set sensors = ( ENVISAT SENTINEL TSX ALOS1 ALOS2 ERS CSK RADARSAT2)
if (`echo $sensors | awk ' {for (i=1;i<=NF;i++) if ($i=="'$sensor'") print 1}'` != 1) then
 echo ""
 echo " ERROR\!\!"
 echo " check the sensor name; it must be one of these: $sensors"
 echo ""
 exit 1
endif

if (! -e $data) then
echo ""
 echo " ERROR\!\!"
 echo " data path $data does not exist"
 echo ""
 exit 1
endif

if (! -e $workdir) then
echo ""
 echo " ERROR\!\!"
 echo " workdir $workdir does not exist"
 echo ""
 exit 1
endif

echo " working directory = $workdir"
echo " data path = $data"
echo " sensor type = $sensor"

if ($sensor == "ALOS1") then
   if ($format == "" ) then
    echo " ERROR\!\!"
    echo " format (ersdac or ceos) is not set"
    exit 1
  else
   echo " format = $format" 
  endif 
   if ( $level == ""  ) then
    echo " ERROR\!\!"
    echo " level (slc ro raw)  is not set"
    exit 1
   else
     echo " level = $level"
   endif
endif



# wait a lit bit to check the paramters printed to screen
sleep 10s
###################  make symbolic links ###########################
#
#  create a folder for each image and then find orbits files link the orbits,  xml and tiff files. 
if (! -e $workdir) then
\mkdir  -p $workdir/SLC
endif

if (! -e $workdir/SLC) then
\mkdir  -p $workdir/SLC
endif

# array for dates
set dts = (x)
# set date number
set slc = 0

cd $workdir/SLC
if ($sensor == "ENVISAT") then
  echo ""
 foreach f (`find $data -name "*N1"`)
  set d = `echo $f:t | awk  '{print substr($1,15,8) }'`
  set df = `echo $f:t | awk  '{print $1 }'`
  if ( -e $d) then
   rm -r $d
  endif
   mkdir $d
   \ln -s $f $d/$df:r.baq 
    # count images
    if ($d  != "$dts[$#dts]") then
     @ slc = $slc + 1
     echo $d
    endif
    set dts = ($dts $d)
 end
  #ls $workdir/SLC
  echo ""
  echo "There are $slc Envisat  images"
  echo ""
 else if ($sensor == "ERS") then
 #ER02_SAR_IM__0P_20050606T080210_20050606T080227_DPA_52952_0000.CEOS
 foreach f (`\ls -d $data/*CEOS`)
  set d = `echo $f:t | awk  '{print substr($1,17,8) }'`
  if (-e $d) then
   rm -r $d
  endif
   mkdir $d
    set dat = `find $f -iname "DAT_*" `
    set ldr = `find $f -iname "LEA_*" `
    ln -sf $dat $d/ERS$d.dat
    ln -sf $ldr $d/ERS$d.ldr
     # count images
    if ($d  != "$dts[$#dts]") then
     @ slc = $slc + 1
     echo $d
    endif
    set dts = ($dts $d)
  end
  #ls $workdir/SLC } xargs
  echo ""
  echo "There are  $slc ERS  images"
  echo ""
 else if ($sensor == "RADARSAT2") then
  # folder containing RS2 SLC data
  # RS2_OK43873_PK423873_DK374693_FQ16_20110515_161531_HH_VV_HV_VH_SLC 
  foreach f (`\ls -d $data/RS2*SLC`)
  set d = `echo $f:t | awk  '{print substr($1,36,8) }'`
  if (-e $d) then
   rm -r $d
  endif
   mkdir $d
    ln -sf $f/*tif $d/
    ln -sf $f/product.xml $d/
    echo "$d"
    # count images
    if ($d  != "$dts[$#dts]") then
     @ slc = $slc + 1
     echo $d
    endif
    set dts = ($dts $d)
  end
  #ls $workdir/SLC } xargs
  echo ""
  echo "There are $level  RADARSAT2 images"
  echo ""
else if ($sensor == "ALOS1" && $format == ersdac && level == slc) then
 foreach f (`find $data/ -iname "*raw"`)
 set d = `echo $f:t | awk -F"/" '{print "20" substr($1,8,6)}'`
 set ldr = $f:r.ldr
   if (! -e $workdir/SLC/$d) then
   mkdir $workdir/SLC/$d   
   endif
     \ln -sf $f $workdir/SLC/$d/IMG-HH-ALPSRP1${d}-H1.1__A
     \ln -sf $ldr $workdir/SLC/$d/LED-ALPSRP1${d}-H1.1__A
     # count images
    if ($d  != "$dts[$#dts]") then
     @ slc = $slc + 1
     echo $d
    endif
    set dts = ($dts $d)
 end  
  #ls $workdir/SLC
  echo ""
  echo "There are $slc ALOS  images"
  echo ""

else if ($sensor == "ALOS1" && $format == ceos && level == raw) then
 foreach f (`find $data/ -iname "LED-ALP*"`)
 set d = `head -c 800 $f | awk '{printf "%s ", $(NF)}' | awk '{print substr($2,1,8)}'`
 set id = `echo $f:t | awk '{print substr($1,11,9)}'`
  if (! -e $workdir/SLC/$d) then
   mkdir $workdir/SLC/$d   
   endif
    foreach  im ( $f:h/IMG*${id}-H1.0__A )
     set pol = `echo $im:t | awk -F- '{print $2}'`
     \ln -sf $im $workdir/SLC/$d/IMG-$pol-ALPSRP1${d}-H1.0__A
    end
     \ln -sf $f $workdir/SLC/$d/LED-ALPSRP1${d}-H1.0__A
     # count images
    if ($d  != "$dts[$#dts]") then
     @ slc = $slc + 1
     echo $d
    endif
    set dts = ($dts $d)
 end  
  #ls $workdir/SLC
  echo ""
  echo "There are $slc ALOS  images"
  echo ""

else if ($sensor == "ALOS2") then
 echo ""
 set dts = (x)
 foreach f (`find $data -iname "IMG*"`)
 set d = `echo $f:t | awk -F"/" '{print "20" substr($1,23,6)}'`
 set ds = `echo $f:t | awk -F"/" '{print  substr($1,23,6)}'`
 set led = `echo $f:h/LE*${ds}* | awk  -F"/" '{print $(NF)}'`
   if (! -e $workdir/SLC/$d) then
    mkdir -p $workdir/SLC/$d   
   endif
     \ln -sf $f $workdir/SLC/$d/
     \ln -sf $f:h/$led $workdir/SLC/$d/
     if ($d  != "$dts[$#dts]") then
      @ slc = $slc + 1
      echo $d
     endif
     set dts = ($dts $d)
end  
  #ls $workdir/SLC
  echo ""
  echo "There are $slc ALOS2 images"
  echo ""
else if ($sensor == "SENTINEL") then
 echo ""
 foreach f (`find $data -iname "*tiff" | sort`)
  set d = `echo $f:t  | awk -F- '{print substr($5,1,8) }'`
  set xml = $f:h:h/annotation/$f:t:r.xml
 if (! -e $d) then
   mkdir $d
  endif
   \ln -sf $f $d/
   \ln -sf $xml $d/
   \ln -sf $f:h:h/preview/quick-look.png ${d}/quick-look$slc.png
    # count images
    if ($d  != "$dts[$#dts]") then
     @ slc = $slc + 1
     echo $d
    endif
    set dts = ($dts $d)
 end
 echo ""
 echo " There are  $slc  SENTINEL images"
 echo ""
else if ($sensor == "TSX") then
echo ""
 foreach f ( `find $data -name "*.cos"`)
  set l = $f:h:h/*xml
  set d = `echo $l:t | awk '{print substr($1,29,8)}'`
 if (! -e $d) then
  mkdir $workdir/SLC/$d
 endif
  ln -sf $l $workdir/SLC/$d/leader.xml
  ln -sf $f $workdir/SLC/$d/image.slc
  cd $workdir/SLC/$d
  #make_slc_tsx leader.xml image.slc TSX TSX$d
  cd $workdir
    # count images
    if ($d  != "$dts[$#dts]") then
     @ slc = $slc + 1
     echo $d
    endif
    set dts = ($dts $d)
 end
  echo ""
  echo "There are  $slc  TSX images"
  echo ""
else if ($sensor == "CSK") then
  echo ""
 foreach f ( `find $data -name "*h5"`)
   set d = `echo $f:t | awk -F_ '{print substr($9,1,8)}'`
 if (! -e $d) then
   mkdir -p $workdir/SLC/$d/
 endif
   ln -sf $f $workdir/SLC/$d/
    # count images
    if ($d  != "$dts[$#dts]") then
     @ slc = $slc + 1
     echo $d
    endif
    set dts = ($dts $d)
  end
  echo ""
  echo "There are  $slc  CSK  images"
  echo ""
endif

cd $workdir



