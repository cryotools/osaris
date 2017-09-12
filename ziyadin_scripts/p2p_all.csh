#!/bin/csh  -f
#
# Script for multi SAR image processing with GMT5SAR and SBAS inversion
#
# Ziyadin Cakir, March 2016
#
if ($#argv < 1) then
echo ""
echo "enter config_file [write scripts=1;  pre proc=1,    inteferos=1;  merge]"
echo ""
echo " ex:$0 config.T43 "
echo " ex:$0 config.T43  1       = write scripts   only " 
echo " ex:$0 config.T43  1 1     = write scripts and run preproc only " 
echo " ex:$0 config.T43  0 1     = skip writing scripts and run preproc only " 
echo " ex:$0 config.T43  0 1 1 1 = run preproc, ifg and merge "
echo " ex:$0 config.T43  0 0 0 1 = run merge only "
echo ""
echo " if writing scripts is skipped then all the previously generated scripts will be run"
echo " therefore, if a new list given manually then scripts should be generated again"
echo ""
set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
kill $PPID
exit 1
endif

#
set config_file = $1
# prepare scripts, run pre_proc_only,  run ifgs only, run both steps
if ($#argv == 2) then
   set yaz = $2
   set pre_proc = 0
   set ifg_proc = 0
   set merge_proc = 0
else if ($#argv == 3) then
  set yaz = $2
  set pre_proc = $3 
  set ifg_proc = 0
  set merge_proc = 0
else if ($#argv == 4) then
  set yaz = $2 
  set pre_proc = $3
  set ifg_proc = $4
  set merge_proc = 0
else if ($#argv >= 5) then
  set yaz = $2 
  set pre_proc = $3
  set ifg_proc = $4
  set merge_proc = $5
else
# no argument given, write scripts and run all
  set yaz = 1
  set ifg_proc = 1
  set pre_proc = 1 
  set merge_proc = 1
endif

if ( ! -e $config_file) then
 echo ""
 echo "$config_file does not exist\!\!"
 echo ""
 set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
 kill $PPID
 exit 1
endif
  echo " +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "                     PARAMETERS DEFINED"
  echo " +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
# set starting multi processing step 
 if ($pre_proc == 1 & $ifg_proc == 0) then
  set start_interferogram_step = 1
 else
  set start_interferogram_step = `grep "proc_stage = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' ` 
 endif
 if ($start_interferogram_step == "") then
  echo ""
  echo " set proc_stage"
  echo ""
  set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
  kill $PPID
  exit 1
 endif
 if ($start_interferogram_step == 1 ) then
  echo " start_interferogram_step  = $start_interferogram_step     (preprocess)"
 else if ($start_interferogram_step == 2 ) then
  echo " start_interferogram_step= $start_interferogram_step       (align SLC images)"
 else if ($start_interferogram_step == 3 ) then
  echo " start_interferogram_step = $start_interferogram_step      (make topo_ra)"
 else if ($start_interferogram_step == 4 ) then
  echo " start_interferogram_step = $start_interferogram_step     (make and filter interferograms) "
 else if ($start_interferogram_step == 5 ) then
  echo " start_interferogram_step = $start_interferogram_step     (unwrap phase)"
 else if ($start_interferogram_step == 6 ) then
  echo " start_interferogram_step = $start_interferogram_step     (geocode)"
 endif

 # set ending  p2p step 
 if ($pre_proc == 1 & $ifg_proc == 0) then
  set  stop_interferogram_step = 1
 else
  set  stop_interferogram_step = `grep "stop_stage = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
 endif
 if ($start_interferogram_step == "") then
  echo ""
  echo " ERROR! set stop_stage"
  echo ""
  exit 1
 endif
 # in case proc start no is less than proc stop no
 if ($stop_interferogram_step < $start_interferogram_step ) then
   echo " "
   #set stop_interferogram_step = $start_interferogram_step
    echo " ERROR stop_interferogram_step < start_interferogram_step"
   exit 1
 endif
 if ($stop_interferogram_step == 1 ) then
  echo " stop_interferogram_step  = $stop_interferogram_step      (preprocess)"
 else if ($stop_interferogram_step == 2 ) then
  echo " stop_interferogram_step= $stop_interferogram_step        (align SLC images)"
 else if ($stop_interferogram_step == 3 ) then
  echo " stop_interferogram_step = $stop_interferogram_step       (make topo_ra)"
 else if ($stop_interferogram_step == 4 ) then
  echo " stop_interferogram_step = $stop_interferogram_step       (make and filter interferograms) "
 else if ($stop_interferogram_step == 5 ) then
  echo " stop_interferogram_step = $stop_interferogram_step       (unwrap phase)"
 else if ($stop_interferogram_step == 6 ) then
  echo " stop_interferogram_step = $stop_interferogram_step       (geocode)"
 endif
endif 

# settings 
# set the senor; ENVISAT, SENTINEL, TSX
set sensor = `grep "sensor = " $config_file| awk '$1 !~/#/ {if ($2 = "=") print $0}'  | awk 'END {print $3}' `# acquisition mode, strip or scan
set mode = `grep "mode = " $config_file| awk '$1 !~/#/ {if ($2 = "=") print $0}'  | awk 'END {print $3}' `
# data format, ersdac
set format = `grep "format = " $config_file| awk '$1 !~/#/ {if ($2 = "=") print $0}'  | awk 'END {print $3}' `# data level, slc or raw
set level = `grep "level = " $config_file| awk '$1 !~/#/ {if ($2 = "=") print $0}'  | awk 'END {print $3}' `
# polarization for RADARSAT
set pol = `grep "pol = " $config_file| awk '$1 !~/#/ {if ($2 = "=") print $0}'  | awk 'END {print $3}' `
# for ALOS
set SLC_factor = `grep  "SLC_factor = " $config_file| awk '$1 !~/#/ {if ($2 = "=") print $0}'  | awk 'END {print $3}' `
# topo phase 
set topo_phase = `grep  "topo_phase = " $config_file| awk '$1 !~/#/ {if ($2 = "=") print $0}'  | awk 'END {print $3}' `
# set starting subswath
set swathS = `grep "swathS = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
# set ending subswath
set swathE = `grep "swathE = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
# set merge 
set merge_swaths = `grep "merge_swaths = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
#
if ($swathS != $swathE) then
 if ( $merge_swaths == "") then
  set merge_swaths = 0 
 endif 
endif
# orbit directory for Sentinel# last bit is used in case there is "/" after at the end of the path
set orbdir = `grep "orbdir = " $config_file| awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk ' END {print $3}'| sed s'/\[ //'`
# path to data 
set data = `grep "data = " $config_file| awk '$1 !~/#/ {if ($2 = "=") print $0}'  | awk 'END {print $3}'| sed s'/\[ //'`
# set full path to the working directory 
set workdir = `grep "workdir = " $config_file| awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk ' END {print $3}'| sed s'/\[ //'`; 
# name of the working directory; usually track number, region etc
set name = `grep "name = " $config_file| awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk ' END {print $3}'| sed s'/\[ //'`; 
if ($name == "") then
 set name = $workdir:t
endif
# set number of cores for multi processing 
set core = `grep "core = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
if ($core == "") then
 set core = 1000
endif
# set time for slrum jobs 
set time_limit = `grep "time_limit = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
if ($time_limit == "") then
 set time_limit = 04:00:00
endif
#SBATCH -N $nodes
#SBATCH -n $ntask
set nodes = `grep "nodes = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
if ($nodes == "") then
 set nodes = 1
endif
set ntask = `grep "ntask = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
if ($ntask == "") then
 set ntask = 1
endif
# set number of simultanous unzipping 
set nzip = `grep "nzip = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
if ($nzip == "") then
 set nzip = 1000
endif
#
set partition = `grep "partition = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
if ($partition == "") then
 echo " ERROR\!\!"
 echo " partition   is not set"
 echo ""
 set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
 kill $PPID
 exit 1
endif
#
set account = `grep "account = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
if ($account == "") then
 echo " ERROR\!\!"
 echo " account  is not set"
 echo ""
 set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
 kill $PPID
 exit 1
endif
#
set name = `grep "name = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
if ($name == "") then
 set name = `whoami | cut -c1-8`
endif
#
# set the master date
set master = `grep "master = " $config_file  | awk '$1 !~/#/ {if ($2 = "=" && $3  > 1000) print $0}'| awk ' END {print $3}' `
# set supermaster
set supermaster = $master
# set threshold_snaphu
set threshold_snaphu = `grep threshold_snaphu $config_file| awk '$1 !~/#/ { if ($2 = "=") print $0}'| awk ' END {print $3}'`
# event date
set event = `grep event $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}'| awk ' END {print $3,$4}'` 
# script processing start
set proc_stage = `grep "proc_stage = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
# script processing stop
set stop_stage = `grep "stop_stage = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
# unwrap region in case there are several subregions in the frame
set unwrap_region_name  = `grep unwrap_region_name $config_file| awk '$1 !~/#/ { if ($2 = "=") print $0}'| awk ' END {print $3}'`
# max defo allowed
set defomax =  `grep defomax $config_file| awk '$1 !~/#/ { if ($2 = "=") print $0}'| awk ' END {printf $3}'`
# geocode
set threshold_geocode =  `grep threshold_geocode $config_file| awk '$1 !~/#/ { if ($2 = "=") print $0}'| awk ' END { print $3}'`; 
# region cut
set region_cut =  `grep region_cut $config_file | awk '$1 !~/#/ {print $0}' | awk ' END {if (NR > 0) print  $3}'` 
set region_cut_geo =  `grep region_cut_geo $config_file | awk '$1 !~/#/ {print $0}' | awk ' END {if (NR > 0) print $3}'` 
if ($region_cut ==  "" && $region_cut_geo == "") then
 echo " no region is given; whole interferogram will be unwrapped"
else
 echo " region_cut = $region_cut"
 echo " region_cut_geo = $region_cut_geo"
endif 
# filter
set filter =   `grep filter_wavelength $config_file| awk '$1 !~/#/ { if ($2 = "=") print $0}'| awk ' END {print $3}'`; 
# interpolate before unwrapping
set interpolate = `grep interpolate $config_file| awk '$1 !~/#/ { if ($2 = "=") print $0}'| awk ' END {print $3}'`
# landmask wet regions
set landmask = `grep switch_land $config_file | awk '$1 !~/#/ { if ($2 = "=") print $0}'| awk ' END { if ($3 == 1) print "yes"; else print "no"}'`
# clean some files
set clean =      `grep clean $config_file | awk '$1 !~/#/ { if ($2 = "=") print $0}' | awk ' END { if ($3 == 1) print $3" (yes)"; else print "no"}'`; 
# # skip goldstein filtering 
set skip_filter_goldstein =     `grep skip_filter_goldstein $config_file| awk '$1 !~/#/ { if ($2 = "=") print $0}'| awk ' END { if ($3 == 1) print "yes"; else print "no"}'`;
# for file size
set dec_factor =  `grep dec_factor $config_file| awk '$1 !~/#/ { if ($2 = "=") print $0}'| awk ' END { print $3}'`; 
# # skip conv filtering 
set skip_filter_conv =     `grep skip_filter_conv $config_file| awk '$1 !~/#/ { if ($2 = "=") print $0}'| awk ' END { if ($3 == 1) print "yes"; else print "no"}'`;
# PS type 
set PS = `grep "PS = " $config_file  | awk '$1 !~/#/ {if ($2 = "=") print $0}'| awk ' END {print $3}' `
# in dir
if ($PS == "SM") then
 set insar_dir = PSI_$master
else if ($PS == "SB") then
 set insar_dir = SBI 
endif
# set perp and temporal baselines
#  Time difference in days for small baseline pairs
set dt = `grep "dt = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
set dts = `grep "dt = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3*86400}'` 
#  Baseline difference in m for small baseline pairs
set db = `grep "db = "  $config_file| awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
set script = $0
# files to be geocoded
set fgeo = `grep _ll $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk '{if ($3 == 1) print $1 }'`
# interfero list
set int_list = `grep int_list $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}'| awk ' END {if (NF > 1) print $3}'` 
####### checking ##############################################################################
# make sure sensor is set correctly
 if ($sensor == "") then
  echo ""
  echo " ERROR\!\!\! set sensor type ( ENVISAT SENTINEL TSX ALOS1 ALOS2 ERS CSK RADARSAT2)"
  echo ""
  set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
  kill $PPID
  exit 1
 endif
set sensors = ( ENVISAT SENTINEL TSX ALOS1 ALOS2 ERS CSK RADARSAT2)
if (`echo $sensors | awk ' {for (i=1;i<=NF;i++) if ($i=="'$sensor'") print 1}'` != 1) then
 echo ""
 echo " ERROR\!\!"
 echo " check the sensor name; it must be one of these: $sensors"
 echo ""
 set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
 kill $PPID
 exit 1
endif
#
 if ($int_list != "") then
  if (! -e $insar_dir/$int_list & ! -e $int_list) then
    echo ""
    echo " $int_list does not exist\!"
    echo ""
    set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
    kill $PPID
    exit 1
  endif
   echo " interferogram list: $int_list"
 endif
#
#
#
if ($threshold_geocode == "") then
  echo ""
  echo " ERROR\!\!\! threshold_geocode is NOT set"
  echo ""
  set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
  kill $PPID
  exit 1
endif
if ( `echo $threshold_geocode | awk '{if ($1  >= 1) print 1; else print 0}'` == 1)  then
  echo ""
  echo " ERROR\!\!\! threshold_geocode should be between 0 and ~1)"
  echo ""
  set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
  kill $PPID
  exit 1
endif
 echo " -------------------------------------------------------------"
 echo " partition = $partition"
 echo " account = $account"
 echo " number of cores = $core"
 echo " time limit = $time_limit"
 echo " nodes (-N) = $nodes"
 echo " ntask (-n) = $ntask"
 echo " -------------------------------------------------------------"
 echo " sensor = $sensor"

 if ($PS == "") then
  echo ""
  echo "set PS type"
  echo ""
  set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
  kill $PPID
  exit 1
 endif
 if ($sensor == "ALOS1" || $sensor == "ALOS2") then
  if ($mode == "" ) then
    echo " ERROR\!\! mode (scan or strip) must be set"
    set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
    kill $PPID 
    exit 1
  else 
    echo " mode = $mode"
  endif
  if ($mode != "scan" && $mode != "strip") then
    echo " ERROR\!\! mode is neither scan nor strip"
    exit 1
  endif
  if ($level == "") then
   echo ""
   echo " ERROR\!\! level (slc or raw) must be set"
   echo ""
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
  k ill $PPID
   exit 1
  else
   echo " level = $level"
  endif 
  if ($level != "slc" && $level != "raw") then
   echo ""
   echo " ERROR\!\! level is not slc or raw"
   echo ""
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
   exit 1
  endif
   if ($format == "") then
   echo ""
   echo " ERROR\!\! format (ersdac or ceos) must be set"
   echo ""
   exit 1
  else 
    echo " format = $format"
  endif
  if ($format != "ersdac" && $format != "ceos") then
    echo ""
    echo " ERROR\!\! level is not ersdac or ceos"
    echo ""
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
    exit 1
  endif
endif
if ($sensor == "ALOS2") then
  if ($swathS == "" ) then
    echo " ERROR\!\!  swathS (starting swath number 1 to 5)  must be set"
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
    exit 1
   endif 
   if ($swathE != "" ) then
    echo " swaths from $swathS to $swathE"
   else 
    set swathE = $swathS
    echo " swaths from $swathS to $swathE"
  endif
    if ($SLC_factor == "") then
    echo ""
    echo " ERROR\!\! SLC_factor is not set"
    echo ""
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPI
    exit 1
  endif
  if ($SLC_factor == "") then
    echo ""
    echo " ERROR\!\! SLC_factor is not set"
    echo  " SLC_factor =  1 for strip "
    echo  " SLC_factor =  1.5 for scansar "
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
    exit 1
  else 
    echo " SLC_factor  =  $SLC_factor"
  endif
endif
 #
 if ($sensor == "CSK") then
  if ($level == "") then
   echo ""
   echo " ERROR\!\! level (slc or raw) must be set"
   echo ""
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
   exit 1
  else if ($level != "slc" && $level != "raw") then
   echo ""
   echo " ERROR\!\! level is not slc or raw"
   echo ""
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
   exit 1
  else
  echo " level = $level"
 endif
endif
#
if ($sensor == "RADARSAT2") then
   if ($mode == "" ) then
    echo " ERROR\!\! mode (scan or strip) must be set"
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
    exit 1
  else 
    echo " mode = $mode"
  endif
  if ($mode != "scan" && $mode != "strip") then
    echo " ERROR\!\! mode is neither scan nor strip"
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
    exit 1
  endif
  if ($pol == "") then
   echo ""
   echo " ERROR\!\!\! pol (polarization) must be set for RADARSAT2"
   echo " VV HH VH or HV"
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
   exit 1
  else 
    echo " polarization = $mode"
  endif
  if ($level == "") then
   echo ""
   echo " ERROR\!\! level (slc or raw) must be set"
   echo ""
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
   exit 1
  else
   echo " level = $level"
  endif 
  if ($level != "slc" && $level != "raw") then
   echo ""
   echo " ERROR\!\! level is not slc or raw"
   echo ""
   exit 1
  endif
   if ($level == "raw") then
   echo ""
   echo " ERROR\!\! no RADARSAT2 raw processor"
   echo " slc data processing only"
   echo " if images are slc (level 1) then"
   echo " set level = slc"
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
   exit 1
  endif
  endif
#
if ($sensor == "ERS") then
 if ($level == "") then
   echo ""
   echo " ERROR\!\! set level = raw "
   echo ""
   exit 1
  else
   echo " level = $level"
  endif 
 if ($level == "slc") then
   echo ""
   echo " ERROR\!\! no ERS slc processor"
   echo " raw data processing only"
   echo " if images are raw (level 0) then"
   echo " set level = raw"
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
   exit 1
  endif
  if ($level != "raw") then
   echo ""
   echo " ERROR\!\! level is not set to raw"
   echo ""
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
   exit 1
  endif
   if ($format == "") then
   echo ""
   echo " ERROR\!\! set level = ceos"
   echo " no envisat format reader for the moment"
   exit 1
  else 
    echo " format = $format"
  endif
  if ($format != "ceos") then
    echo ""
    echo " ERROR\!\! level is not set to ceos"
    echo ""
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID

    exit 1
  endif
 endif
#
if ($sensor == "ENVISAT") then
   if ($level == "") then
   echo ""
   echo " ERROR\!\! set level = raw "
   echo ""
   exit 1
  else
   echo " level = $level"
  endif 
 if ($level == "slc") then
   echo ""
   echo " ERROR\!\! no ENVISAT slc processor"
   echo " raw data processing only"
   echo " if images are raw (level 0) then"
   echo " set level = raw"
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
   exit 1
  endif
  if ($level != "raw") then
   echo ""
   echo " ERROR\!\! level is not set to raw"
   echo ""
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
   exit 1
  endif
 endif
#
 if ($sensor == "SENTINEL") then
  if ($mode == "" ) then
    echo " ERROR\!\! mode (iw [i.e.TOPS] or strip) must be set"
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
    exit 1
  else 
    #echo " mode = $mode"
  endif
  if ($mode != "iw" && $mode != "strip") then
    echo " ERROR\!\! mode is neither iw nor strip"
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
    exit 1
  endif
   if ($swathS == "" ) then
   echo ""
    echo " ERROR\!\!  swathS (starting swath number)  must be set"
   echo " 1,2,3 for VH 4,5,6 for VV"
   exit 1
  endif
  if ($swathE == "" ) then
   set swathE = $swathS
  endif  
  if ($swathS == $swathE) then
   set merge_swaths = 0
  endif   
  if ($orbdir == "" ) then
   echo ""
   echo " ERROR\!\!  orbit dir  must be set"
   echo ""
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
   exit 
  endif
   echo " mode = $mode"
   echo " swathS = $swathS" 
   echo " swathE = $swathE"
   if ($swathS != $swathE) then
    if ( $merge_swaths == 1) then
     echo  " merge_swaths = yes"
    else
     echo  " merge_swaths = no"
    endif 
   endif
   echo " orbit directory = $orbdir"
endif
  echo " working directory = $workdir"
  echo " data directory    = $data"
 #
if ($workdir == "") then
 echo ""
 echo "ERROR\!\! set workdir path"
 echo ""
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
 exit 1
endif
#
if ($master == "") then
 echo ""
 echo " ERROR! set master date"
 echo ""
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
 exit 1
endif 
#
 echo " -------------------------------------------------------------"
 if ($PS == "SB") then
  echo " PS type = SB (Small Baselines)"
  echo " temporal baselines = $dt days"
  echo " spatial baselines = $db m"
 else if ($PS == "SM") then
  echo " PS type = SM (Single Master)"
 else
  echo "PS type or $config_file is wrong"
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
  exit 1
 endif
  #echo " data path = $data"
 #echo " name = $name                         (used in screen name)"
 if (`echo $event | awk '{print $1}'` == "") then
  echo " master date = $master"
 endif
 #
  if ($#event > 0 ) then
  echo " event date = $event"
 endif
# for stripmap images
  if ($swathS == "" ) then
    set swathS = 1
    echo " interferogram directory = F1"
   endif
 echo " -------------------------------------------------------------"
 echo " grdlandmask = $landmask" 
 echo " filter_wavelength = $filter" 
 echo " skip Goldstein filtering = $skip_filter_goldstein" 
 echo " skip conv filtering = $skip_filter_conv" 
 #
if ($interpolate == "") then
   echo ""
   echo " interpolate before unwrapping is not set; assumed no = 0"
   set interpolate = 0
else
   set interpolate = yes
endif
  #
if ($threshold_snaphu == 0) then
  echo " threshold_snaphu is set to  $threshold_snaphu; unwrapping will be skipped..."
else
  if ($defomax == "") then
   echo ""
   echo " ERROR! set master date"
   echo ""
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
   exit 1
  endif
   echo " threshold_snaphu =  $threshold_snaphu" 
   echo " region_cut = $region_cut"
   echo " interpolate before unwrapping = $interpolate"
   echo " maximum deformation (cycle) allowed in snaphu = $defomax " 
  endif 
 endif
#
if ($topo_phase == 1) then
 set dem_file = `grep  "dem_file = " $config_file| awk '$1 !~/#/ {if ($2 = "=") print $0}'  | awk 'END {print $3}' `
 if (! -e $dem_file) then
  echo ""
  echo " ERROR! $dem does not exists"
  echo ""
  set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
  kill $PPID
  exit 1
 endif
set dem4subswath = `grep  "dem4subswath = " $config_file| awk '$1 !~/#/ {if ($2 = "=") print $0}'  | awk 'END {print $3}' `
if ($dem4subswath == "" ) then
 set dem4subswath = 0
endif
else
  echo ""
  echo " ATTENTION\!\! topo_phase is  set to 0; topo phase will NOT be removed from the interfero..."
endif
#
  if ($#event > 0) then
  echo " event date = $event"
 endif
#
 if ($stop_interferogram_step == 6) then
  if ($#fgeo > 0) then
   echo " -------------------------------------------------------------"
   echo " files to be geocoded:"
   grep _ll $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' |awk '{if ($3 == 1) print "", $1 }'
  endif
 endif
   echo " -------------------------------------------------------------"
#
 echo " clean = $clean "
 echo " +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"


echo " starting to process $sensor $mode $level data..."
  echo " write  scripts           =" `echo $yaz | awk ' { if ( $1 == 1 ) print "yes" ; else print "no"}'` 
 if ($sensor == "SENTINEL") then
  echo " run pre process  scripts =" `echo $pre_proc | awk ' { if ( $1 == 1 ) print "yes" ; else print "no"}'` 
  echo " run interfero scripts    =" `echo $ifg_proc | awk ' { if ( $1 == 1 ) print "yes" ; else print "no"}'` 
  echo " run merging   scripts    =" `echo $merge_proc | awk ' { if ( $1 == 1 ) print "yes" ; else print "no"}'` 
 else
  echo " run interfero scripts    =" `echo $ifg_proc | awk ' { if ( $1 == 1 ) print "yes" ; else print "no"}'` 
 endif 
echo ""

echo " check the parameters above"
echo ""
#goto xxx
# wait a lit bit to check the parameters printed to screen
sleep 20s
if ($yaz == 0 ) then
 echo " running scripts only"
 goto scripts
endif
###############################################################################
cd $workdir
## check if SM or SB is set and create ifg list and directoris
if ($PS == "SM") then
 if (! -e SLC/$master) then
   echo ""
   echo "master $workdir/SLC/$master does not exist"
   echo ""
   exit 1
 endif
 if (! -e $workdir/$insar_dir/queue) then
  mkdir -p $workdir/$insar_dir/queue
 endif
 # go to InSAR directory
 cd $workdir/$insar_dir
 if ( $int_list == "" ) then
  set int_list = $workdir/$insar_dir/make_ifg.list
 endif
 # get ifg list
  if (! -e $int_list) then
   if (-e $workdir/$int_list) then
    cp $workdir/$int_list .
    echo "copying $int_list from $workdir"
   else 
    \ls -d $workdir/SLC/[1,2]*[0-9] | awk -F"/" '{print $(NF)}' | sed "/$master/ d" | awk '{print '$master',$1}'> ! $int_list
  endif
 endif
#
 if (`wc -l $int_list | awk '{print $1}'` == 0) then
   echo ""
   echo  "$int_list is empty"
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
    kill $PPID
    exit 1
 endif
 # count ifgs
 set n_ifg = `wc -l $int_list | awk '{print $1}'`
else if ($PS == "SB") then
  if (! -e $workdir/$insar_dir/queue) then
   \mkdir  -p $workdir/$insar_dir/queue
  endif
  cd $workdir/$insar_dir
 if ( $int_list == "" ) then
 if ($#event > 0) then 
   set int_list = make_event_ifg.list
   set ed =  ` date -d "$event"  +%s `  
     if ( -e  $workdir/$insar_dir/make_event_ifg.list ) then
      #    echo "copying make_event_ifg.list from $workdir"
        rm  -f  $workdir/$insar_dir/make_event_ifg.list 
      endif 
      if (-e $workdir/baselines.dat) then
       echo " pairing images within $dt days before and after $event with baselines less than $db m"
       echo " make sure all image in SLC folder are in the baselines.dat" 
       echo " if not, all images within $dt days before and after $event will be processed "
       echo ""
      else
       echo " $workdir/baselines.dat does not exist, pairing all images within $dt days before and after $event "
       echo ""
      endif
      foreach mmdate ( `\ls -d  $workdir/SLC/[0-9]* | awk -F"/" '{print $NF}'` )
       set mdate = `find  $workdir/SLC/$mmdate/ -name "*tiff" | awk -F"/" 'NR==1{print substr($NF,16,8), substr($NF,25,2)":"  substr($NF,27,2)":"  substr($NF,29,2)}' `
      set md =  ` date -d "$mdate"  +%s `
      if ($md <= $ed) then
         foreach ssdate ( `\ls -d  $workdir/SLC/[0-9]* | awk -F"/" '{print $NF}' ` )
          set sdate = `find  $workdir/SLC/$ssdate/ -name "*tiff" | awk -F"/" 'NR==1{print substr($NF,16,8), substr($NF,25,2)":"  substr($NF,27,2)":"  substr($NF,29,2)}' `
          set sd =  ` date -d "$sdate"  +%s `     
          if ( $md <= $ed  &&  $sd >= $ed && $ed - $md <= $dts && $sd - $ed <= $dts) then
	   if (-e $workdir/baselines.dat) then
	     set b1 = ` grep $mmdate $workdir/baselines.dat| awk '{print $2}'`
              if ($b1 == "") then
               echo " $mmdate is not in the baselines.dat list"
               set b1 = 0
               set b2 = 0
              endif 	     
	      set b2 = ` grep $ssdate $workdir/baselines.dat| awk '{print $2}'` 
              if ($b2 == "") then
               echo " $ssdate is not in the baselines.dat list"
               set b1 = 0
               set b2 = 0
              endif 	     
             set baz = `echo $b1 $b2 | awk '{print int(sqrt(($1-$2)*($1-$2)))}'`            
	     if ($baz <= $db) then
              echo $mdate[1] $sdate[1] $baz >>! $workdir/$insar_dir/make_event_ifg.list
              echo "$mdate[1] $sdate[1] $baz m"
	     endif
	   else
            echo $mdate[1] $sdate[1] $baz >>! $workdir/$insar_dir/make_event_ifg.list
	    #echo "$mdate[1] $sdate[1] $baz m"
	   endif
          endif
         end
       endif
      end
  else
   set int_list = make_sb_ifg.list
  endif
 endif
  # if ifg list exists use it otherwise get it from PS folder or workdir
  if (! -e  $int_list) then 
   if (-e $workdir/$int_list) then
    cp $workdir/$int_list .
    echo "copying $int_list from $workdir"
   else 
    if (-e $workdir/${insar_dir}/make_sb_ifg.list) then 
     echo "$int_list does not exist\!\!"
     echo "copying make_sb_ifg.list from $workdir/${insar_dir}"
     cp $workdir/${insar_dir}/make_sb_ifg.list $int_list
    else
     echo " $workdir/${insar_dir}/make_sb_ifg.list or $int_list does not exist"
     set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
     kill $PPID
     exit 1
    endif
   endif  
  endif
 # count ifgs
 set n_ifg = `wc -l $int_list | awk '{print $1}'`
endif
echo ""
echo "$n_ifg pairs of images  will be calculated:"
echo "----------------------------------------------------------------------------"
cat $int_list
if ($PS == "SB" & $#event == 0) then
 if ( `cat $int_list | awk '{print $3}' | gmtinfo -C | awk '{if ($1 < -'$db' || $2 > '$db') print 1; else print 0}'` > 0 ) then
 echo ""
 echo " some of the baselines are larger than $db m"
 echo " re run  calc_plot_top_baselines.csh to see the new SBAS network "
 echo " use flag 2 to skip baseline calculation" 
 echo " e.g. calc_plot_top_baselines.csh config.T43 2"
 echo "" 
 set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
 kill $PPID
 exit 1
 endif
endif
echo ""
sleep 10s

cd $workdir/$insar_dir
#
# remove files for job array in case re running
#
if (`find $workdir/$insar_dir/queue -name "*sh" | wc -l` > 0 ) then
 rm $workdir/$insar_dir/queue/F*/*sh
endif
#
# loop for ifg number
set n = 1
foreach f (`cat $int_list | awk 'NF > 1 {print $1"_"$2}'`) 
 set slave  = (`echo $f | awk -F_ '{print $2}'`)
 set master = (`echo $f | awk -F_ '{print $1}'`)
  
# see if master of slave folder is missing
if (! -e $workdir/SLC/$master || ! -e $workdir/SLC/$slave) then
 echo ""
 echo "   CHECK OUT $master or $slave does not exist \!\!"
 echo "                 skipping"
 goto atla
endif
#
# make intefero directory
 if (! -e $f) then
  \mkdir -p $f
 endif
 # go to intefero directory
 cd $f
 # multi subswath processings for Sentinel
 set i = $swathS
 # loop over subswaths 
  while ($i <= $swathE)
   if (! -e $workdir/$insar_dir/preproc_F$i) then
    #mkdir -p $workdir/$insar_dir/preproc_F$i
   endif
   if (! -e $workdir/$insar_dir/queue/F$i) then
    mkdir -p $workdir/$insar_dir/queue/F$i
   endif
    # get number for vv polarization file 
   #@ ifn = $i + 3
    @ ifn = $i
   # create the subswath directory with the raw and topo directories in it
   set proc = proc_F${i}
   if (! -e $proc) then
   \mkdir $proc
   endif
   if (! -e F$i) then
    mkdir  F$i
    endif
   if (! -e F$i/raw) then
    mkdir -p F$i/raw
   endif
    if (! -e F$i/topo) then
    mkdir -p  F$i/topo
   endif
   # link  the topo file 
   ln -sf $workdir/topo/dem.grd F$i/topo/
   # link topo_ra if exits 
   #if ( -e $workdir/topo/topo_ra.grd) then
   #  ln -sf $workdir/topo/topo_ra.grd F$i/topo/
   #endif
   #link  the raw data
 if ($sensor == "ENVISAT") then
    ln -sf $workdir/SLC/$master/* F$i/raw/
    ln -sf $workdir/SLC/$slave/* F$i/raw/
    set mbaq = `find $workdir/SLC/$master/ -name "ASA*baq" | awk -F "/" '{print $(NF)}'`   
    set sbaq = `find $workdir/SLC/$slave/ -name "ASA*baq" | awk -F "/" '{print $(NF)}'` 
  else if ($sensor == "ERS") then   
    ln -sf $workdir/SLC/$master/ERS$master.dat  F$i/raw/ERS$master.dat
    ln -sf $workdir/SLC/$slave/ERS$slave.dat  F$i/raw/ERS$slave.dat
    ln -sf $workdir/SLC/$master/ERS$master.ldr  F$i/raw/ERS$master.ldr
    ln -sf $workdir/SLC/$slave/ERS$slave.ldr  F$i/raw/ERS$slave.ldr
   else if ($sensor == "RADARSAT2") then   
    ln -sf $workdir/SLC/$master/product.xml  F$i/raw/RS2${master}.xml
    ln -sf $workdir/SLC/$slave/product.xml  F$i/raw/RS2${slave}.xml
    ln -sf $workdir/SLC/$master/imagery_${pol}.tif  F$i/raw/RS2${master}_${pol}.tif
    ln -sf $workdir/SLC/$slave/imagery_${pol}.tif  F$i/raw/RS2${slave}_${pol}.tif
 else if ($sensor == "ALOS1" && $mode == "strip") then 
    ln -sf $workdir/SLC/$master/* F$i/raw/
    ln -sf $workdir/SLC/$slave/* F$i/raw/
  else if ($sensor == "ALOS2" && $mode == "strip") then 
    ln -sf $workdir/SLC/$master/* F$i/raw/
    ln -sf $workdir/SLC/$slave/* F$i/raw/
    set masterIM = `find $workdir/SLC/$master/ -name "IMG-*" | awk -F "/" '{print $(NF)}'`
    set slaveIM  = `find $workdir/SLC/$slave/ -name "IMG-*" | awk -F "/" '{print $(NF)}'`
  else if ($sensor == "ALOS2" && $mode == "scan") then
   # image
    set lnm = `find $workdir/SLC/$master/ -name "IMG-*-F${i}" | awk -F "/" '{print $(NF)}'`
    set lns  = `find $workdir/SLC/$slave/  -name "IMG-*-F${i}" | awk -F "/" '{print $(NF)}'`
    set masterIM = ` echo $lnm  | awk '{print substr($(NF),1,(length($(NF))-3))}'`
    set slaveIM = ` echo $lns  | awk '{print substr($(NF),1,(length($(NF))-3))}'`
    set dm = `echo $masterIM | awk -F- '{print $4}'`
    set ds = `echo $slaveIM | awk -F- '{print $4}'`
    ln -sf $workdir/SLC/$master/$lnm F$i/raw/$masterIM
    ln -sf $workdir/SLC/$slave/$lns   F$i/raw/$slaveIM
    # xml
    set lnmx = `find $workdir/SLC/$master/ -name "LED-*-${dm}-*" | awk -F "/" '{print $(NF)}'`
    set lnsx  = `find $workdir/SLC/$slave/  -name "LED-*-${ds}-*" | awk -F "/" '{print $(NF)}'`
    ln -sf $workdir/SLC/$master/$lnmx F$i/raw/
    ln -sf $workdir/SLC/$slave/$lnsx   F$i/raw/
    else if ($sensor == "CSK") then 
    ln -sf $workdir/SLC/$master/* F$i/raw/
    ln -sf $workdir/SLC/$slave/* F$i/raw/
    else if ($sensor == "TSX") then  
     ln -sf $workdir/SLC/$master/image.slc $proc/TSX$master.cos
     ln -sf $workdir/SLC/$slave/image.slc $proc/TSX$slave.cos
     ln -sf $workdir/SLC/$master/leader.xml $proc/TSX$master.xml
     ln -sf $workdir/SLC/$slave/leader.xml $proc/TSX$slave.xml
   else if ($sensor == "SENTINEL") then 
    # check if vv polorization file numbered between 4 and 6 (=$ifn) exists. if not, use vh file numbered between 1 and 3 (=$i)
    # master files. 
    # Files must be sorted based on acquition time if there is more than one frame to sticth. This is automaticaly done during the
    # setting, e.g. et imM  = $workdir/SLC/$master/*-00${i}.tiff
#  if (`find $workdir/SLC/$master/ -name "*-00${ifn}.tiff" | wc -l` >= 1) then
#      set imM  = $workdir/SLC/$master/*-00${ifn}.tiff
#      set imMp = vv
#      set swn = ${ifn}
#     else 
#      if (`find $workdir/SLC/$master/ -name "*-00${i}.tiff" | wc -l` >= 1) then
#       set imM  = $workdir/SLC/$master/*-00${i}.tiff
#       set imMp = vh
#       set swn = $i
#      else
#       set imM = ""
#      endif 
#     endif
#     # xml file
#     if (`find $workdir/SLC/$master/ -name "*-${imMp}-*-00${swn}.xml" | wc -l` >= 1) then
#      set xM   = $workdir/SLC/$master/*-00${swn}.xml
#     else 
#      set xM = ""
#     endif
#      # slave files
#     if (`find $workdir/SLC/$slave/ -name "*-${imMp}-*-00${swn}.tiff" | wc -l` >= 1) then
#      set imS  = $workdir/SLC/$slave/*-00${swn}.tiff
#     else
#      set imS = ""
#     endif
#    if (`find $workdir/SLC/$slave/ -name "*-${imMp}-*-00${swn}.xml" | wc -l` >= 1) then
#      set xS   = $workdir/SLC/$slave/*-00${swn}.xml
#     else 
#      set xS = ""
#     endif
    
    
     if (`find $workdir/SLC/$master/ -name "*-00${i}.tiff" | wc -l` >= 1) then
      set imM  = $workdir/SLC/$master/*-00${i}.tiff
     else
      set imM = ""
     endif 
    # xml file
    if (`find $workdir/SLC/$master/ -name "*-00${i}.xml" | wc -l` >= 1) then
     set xM   = $workdir/SLC/$master/*-00${i}.xml
    else 
     set xM = ""
    endif
     # slave files
    if (`find $workdir/SLC/$slave/ -name "*-00${i}.tiff" | wc -l` >= 1) then
     set imS  = $workdir/SLC/$slave/*-00${i}.tiff
    else
     set imS = ""
    endif
   if (`find $workdir/SLC/$slave/ -name "*-00${i}.xml" | wc -l` >= 1) then
     set xS   = $workdir/SLC/$slave/*-00${i}.xml
    else 
     set xS = ""
    endif
   
    # check if files exist
    #echo $xM 
    #echo $xS 
    #echo $imM 
    #echo $imS
    if ( $xM[1] == "" | $xS[1] == "" | $imM[1] == "" | $imS[1] == "" ) then
     echo ""
     echo "  skipping $master"_"$slave"_F"$i, master or slave file is missing"
     echo "  check swath number"
     goto atla
    endif

    ln -sf $xM $proc/
    ln -sf $xS $proc/
    ln -sf $imM $proc/
    ln -sf $imS $proc/
     # satellite ID
     # get satellite A or B
      set mSAT = `echo $xM:t | cut -c1-3 | tr '[:lower:]' '[:upper:]'`
      set sSAT = `echo $xS:t | cut -c1-3 | tr '[:lower:]' '[:upper:]'`
   
    # get orbit files for tops
    if ($mode == "iw")  then
     # get the hour of aquition
     #set saatM = `echo $xM:t:r | awk -Ft '{print substr($2,1,6)}'`
     #set saatS = `echo $xS:t:r | awk -Ft '{print substr($2,1,6)}'`
     # subtract 1 day from the dates
     set dM = `date -d "$master - 1 day" +%Y%m%d`
     set dS = `date -d "$slave  - 1 day" +%Y%m%d`
 
     # find the orbit file for the master 
      set orbM = `\ls  -la  $orbdir/aux_poeorb/${mSAT}* | awk  '{print $(NF)}'| awk -F"/" '{print $(NF) }'| awk -F_ '{print substr($7,2,8),substr($8,1,8), $0}' | awk ' {if ($1 == '$dM' ) print $3}'| awk 'NR==1 {print $0}' `
     # if there is no precise orbit (which is available atfer 3 weeks) get the  resituated orbit available within 3 hours after the acquisition
     if ($#orbM == 0) then
      # get full acquisition time of the master 
      set at = `\ls $workdir/SLC/$master/*-00${i}.xml | awk -F"/" 'NR==1 {print substr($NF,16,8)  substr($NF,25,6)}'`
      set orbM = `\ls -l  $orbdir/aux_resorb/${mSAT}* | awk  '{print $(NF)}'| awk -F"/" '{print $(NF) }'| awk -F_ '{print substr($7,2,8),substr($8,1,8), $0}' | awk '{if ($1 == ('$master') ) print $3}' | awk -F_ '{print substr($7,2,8) substr($7,11,6),substr($8,1,8) substr($8,10,6), $0}' | awk '{if ($2 >= '$at' && $1 <= '$at' ) print $0}' | awk 'NR==1 {print $3}' `
     endif
    
      # find the orbit file for the slave
      set orbS = `\ls  -la  $orbdir/aux_poeorb/${sSAT}* | awk  '{print $(NF)}'| awk -F"/" '{print $(NF) }'| awk -F_ '{print substr($7,2,8),substr($8,1,8), $0}' | awk '{if ($1 == '$dS' ) print $3}' | awk 'NR==1 {print $0}' `
      # if there is no precise orbit (which is available atfer 3 weeks) get the  resituated orbit available within 3 hours after the acquisition
     if ($#orbS == 0) then
      # get full acquisition time of the slave 
      set at = `\ls $workdir/SLC/$slave/*-00${i}.xml | awk -F"/" 'NR==1 {print substr($NF,16,8)  substr($NF,25,6)}'`
      set orbS = `\ls -l  $orbdir/aux_resorb/${sSAT}* | awk  '{print $(NF)}'| awk -F"/" '{print $(NF) }'| awk -F_ '{print substr($7,2,8),substr($8,1,8), $0}' | awk '{if ($1 == ('$slave') ) print $3}' | awk -F_ '{print substr($7,2,8) substr($7,11,6),substr($8,1,8) substr($8,10,6), $0}' | awk '{if ($2 >= '$at' && $1 <= '$at' ) print $0}' | awk 'NR==1 {print $3}' `    
     endif
       #\cp $orbdir/*/$orbM $proc/
       #\cp $orbdir/*/$orbS $proc/
     #
     # check if orbit files exist
     if ( $orbM == "" | $orbS == ""  ) then
      echo ""
      echo "  skipping $master"_"$slave"_"$i, master or slave orbits is missing"
      echo "$master $slave $i" >>! $workdir/missingones.txt
      echo ""
      goto atla
     else
       ln -sf $orbdir/*/$orbM  $proc/
       ln -sf $orbdir/*/$orbS  $proc/
       # not used
      if ($PS == "XXXX") then  
        # for pre proc
       if ($n == 1 ) then
         ln -sf $orbdir/*/$orbM $workdir/$insar_dir/preproc_F${i}/
         ln -sf $xM $workdir/$insar_dir/preproc_F${i}/
         ln -sf $imM $workdir/$insar_dir/preproc_F${i}/
         echo $xM:t:r | awk '{for (i=1; i <= NF; i++) printf"%s:", $i }' > !  $workdir/$insar_dir/preproc_F${i}/frames.in
         echo $orbM >> $workdir/$insar_dir/preproc_F${i}/frames.in
         ln -sf $xS $workdir/$insar_dir/preproc_F${i}/
         ln -sf $imS $workdir/$insar_dir/preproc_F${i}/
         ln -sf $orbdir/*/$orbS $workdir/$insar_dir/preproc_F${i}/
         echo $xS:t:r | awk '{for (i=1; i <= NF; i++) printf"%s:", $i }' >> $workdir/$insar_dir/preproc_F${i}/frames.in
         echo $orbS >> $workdir/$insar_dir/preproc_F${i}/frames.in
       else 
         ln -sf $xS $workdir/$insar_dir/preproc_F${i}/
         ln -sf $imS $workdir/$insar_dir/preproc_F${i}/
         ln -sf $orbdir/*/$orbS $workdir/$insar_dir/preproc_F${i}/
         echo $xS:t:r | awk '{for (i=1; i <= NF; i++) printf"%s:", $i }' >> $workdir/$insar_dir/preproc_F${i}/frames.in
         echo $orbS >> $workdir/$insar_dir/preproc_F${i}/frames.in
        endif
       endif
      endif
     endif
    # loop for sensors
   endif
#################################################################################
# write processing script 
##################################################################################

   if ($sensor == "ENVISAT") then
   cat <<son> ${master}_${slave}_F${i}.sh 
#!/bin/csh -f
# link raw directory that contains orbit file to proc diretory for plotting baselines
\rm -r ${workdir}/${insar_dir}/${f}/${proc}
ln -sf ${workdir}/${insar_dir}/${f}/F${i}/raw  ${workdir}/${insar_dir}/${f}/${proc}
cd ${workdir}/${insar_dir}/${f}/F${i}
p2p_ENVI.csh $mbaq:r $sbaq:r ${workdir}/${config_file}
son
   else if ($sensor == "ERS") then
   cat <<son> ${master}_${slave}_F${i}.sh 
#!/bin/csh -f
\rm -r ${workdir}/${insar_dir}/${f}/${proc}
ln -sf ${workdir}/${insar_dir}/${f}/F${i}/raw  ${workdir}/${insar_dir}/${f}/${proc}
cd ${workdir}/${insar_dir}/${f}/F${i}
p2p_ERS_multi.csh ERS$master ERS$slave ${workdir}/${config_file}
son
   else if ($sensor == "RADARSAT2") then
   cat <<son> ${master}_${slave}_F${i}.sh 
#!/bin/csh -f
cd ${workdir}/${insar_dir}/${master}_${slave}/F$i/raw/
make_slc_rs2 RS2$master.xml RS2${master}_${pol}.tif RS2${master}
make_slc_rs2 RS2$slave.xml  RS2${slave}_${pol}.tif RS2${slave}
# exted the orbits no harm doing it!
extend_orbit RS2${master}.LED tmp 3.
\mv tmp RS2${master}.LED
extend_orbit RS2${slave}.LED tmp 3.
\mv tmp RS2${slave}.LED
ln -sf ${workdir}/${insar_dir}/${f}/F${i}/raw  ${workdir}/${insar_dir}/${f}/${proc}
cd ${workdir}/${insar_dir}/${f}/F${i}
p2p_RS2_SLC_multi.csh RS2${master} RS2${slave} ${workdir}/${config_file}
son
   else if ($sensor == "ALOS1" && $mode == "strip") then
     if ($format == ersdac && $level == "raw" ) then
   cat <<son> ${master}_${slave}_F${i}.sh 
#!/bin/csh -f
\rm -r ${workdir}/${insar_dir}/${f}/${proc}
ln -sf ${workdir}/${insar_dir}/${f}/F${i}/raw  ${workdir}/${insar_dir}/${f}/${proc}
cd ${workdir}/${insar_dir}/${f}/F${i}
p2p_ALOS_multi.csh IMG-HH-ALPSRP1${master}-H1.1__A IMG-HH-ALPSRP1${slave}-H1.1__A ${workdir}/${config_file}
son
  else  if ($format == ceos && $level == "raw") then
   cat <<son> ${master}_${slave}_F${i}.sh 
#!/bin/csh -f
\rm -r ${workdir}/${insar_dir}/${f}/${proc}
ln -sf ${workdir}/${insar_dir}/${f}/F${i}/raw  ${workdir}/${insar_dir}/${f}/${proc}
cd ${workdir}/${insar_dir}/${f}/F${i}
p2p_ALOS_multi.csh IMG-HH-ALPSRP1${master}-H1.0__A IMG-HH-ALPSRP1${slave}-H1.0__A ${workdir}/${config_file}
son
  else  if ($format == ceos && $level == "slc") then
   cat <<son> ${master}_${slave}_F${i}.sh 
#!/bin/tcsh -f
\rm -r ${workdir}/${insar_dir}/${f}/${proc}
ln -sf ${workdir}/${insar_dir}/${f}/F${i}/raw  ${workdir}/${insar_dir}/${f}/${proc}
cd ${workdir}/${insar_dir}/${f}/F${i}
p2p_ALOS_SLC_multi.csh IMG-HH-ALPSRP1${master}-H1.1__A IMG-HH-ALPSRP1${slave}-H1.1__A ${workdir}/${config_file}
son
    endif
   else if ($sensor == "ALOS2") then
     if ($mode == "strip") then
  cat <<son> ${master}_${slave}_F${i}.sh 
#!/bin/csh -f
\rm -r ${workdir}/${insar_dir}/${f}/${proc}
ln -sf ${workdir}/${insar_dir}/${f}/F${i}/raw  ${workdir}/${insar_dir}/${f}/${proc}
cd ${workdir}/${insar_dir}/${f}/F${i}
p2p_ALOS2_SLC_multi.csh $masterIM $slaveIM ${workdir}/${config_file} 
son
     else
   cat <<son> ${master}_${slave}_F${i}.sh 
#!/bin/csh -f
\rm -r ${workdir}/${insar_dir}/${f}/${proc}
ln -sf ${workdir}/${insar_dir}/${f}/F${i}/raw  ${workdir}/${insar_dir}/${f}/${proc}
cd ${workdir}/${insar_dir}/${f}/F${i}
p2p_ALOS2_SCAN_SLC.csh  $masterIM $slaveIM ${workdir}/${config_file}
son
     endif
   else if ($sensor == "TSX") then
   cat <<son> ${master}_${slave}_F${i}.sh 
#!/bin/csh -f
cd ${workdir}/${insar_dir}/${master}_${slave}/${proc}
# exted the orbits no harm doing it!
if (! -e TSX$master.SLC || ! -e TSX$master.PRM || ! -e TSX$master.LED) then
 make_slc_tsx TSX$master.xml TSX$master.cos TSX$master
 extend_orbit TSX${master}.LED tmp 3.
 \mv tmp TSX${master}.LED
 ln -sf ${workdir}/${insar_dir}/${f}/${proc}/TSX$master.[A-Z]?? ${workdir}/${insar_dir}/${f}/F${i}/raw/
endif
if (! -e TSX$slave.SLC || ! -e TSX$slave.PRM || ! -e TSX$slave.LED) then
 make_slc_tsx TSX$slave.xml TSX$slave.cos TSX$slave
 extend_orbit TSX${slave}.LED tmp 3.
 \mv tmp TSX${slave}.LED
 ln -sf ${workdir}/${insar_dir}/${f}/${proc}/TSX$slave.[A-Z]?? ${workdir}/${insar_dir}/${f}/F${i}/raw/
endif
cd ${workdir}/${insar_dir}/${master}_${slave}/F${i}
p2p_TSX_SLC.csh TSX${master} TSX${slave} ${workdir}/${config_file}
son
   else if ($sensor == "CSK" && $level == "raw") then
    cat <<son> ${master}_${slave}_F${i}.sh 
#!/bin/csh -f
cd ${workdir}/${insar_dir}/${master}_${slave}/F${i}/raw/
make_raw_csk ${masterIM} CSK${master}
make_raw_csk ${slaveIM} CSK${slave}
cd ${workdir}/${insar_dir}/${master}_${slave}/F${i}
p2p_CSK_multi.csh CSK${master} CSK${slave} ${workdir}/${config_file}
son
   else if ($sensor == "CSK" && $level == "slc") then    
   cat <<son> ${master}_${slave}_F${i}.sh 
#!/bin/csh -f
cd ${workdir}/${insar_dir}/${master}_${slave}/F${i}/raw/
make_slc_csk ${masterIM} CSK${master}
make_slc_csk ${slaveIM} CSK${slave}
cd ${workdir}/${insar_dir}/${master}_${slave}/F${i}
p2p_CSK_SLC_multi.csh CSK${master} CSK${slave} ${workdir}/${config_file}
son
   else if ($sensor == "SENTINEL" && $mode == "strip") then
cat <<son> ! ${master}_${slave}_F${i}.sh 
#!/bin/csh -f
if ($proc_stage == 1) then
# skip  align_tops.csh if the scrip is reruning
if (! -e ${workdir}/${insar_dir}/${f}/F${i}/raw/${mSAT}${master}_ALL_F${swno}.PRM || ! -e ${workdir}/${insar_dir}/${f}/F${i}/raw/${sSAT}${slave}_ALL_F${swno}.PRM || ! -e ${workdir}/${insar_dir}/${f}/F${i}/raw/${mSAT}${master}_ALL_F${swno}.SLC || ! -e ${workdir}/${insar_dir}/${f}/F${i}/raw/${sSAT}${slave}_ALL_F${swno}.SLC) then
# go to pre-processing folder
cd ${workdir}/${insar_dir}/${f}/${proc}
make_slc_s1a $xM $imM $mSAT$master
make_slc_s1a $xS $imS $sSAT$slave
# link the files
ln -sf ${workdir}/${insar_dir}/${f}/${proc}/S1* ${workdir}/${insar_dir}/${f}/F${i}/raw/
#
cd ${workdir}/${insar_dir}/${f}/F${i}/raw/
extend_orbit $mSAT$master.LED tmp 2.
mv tmp $mSAT$master.LED
extend_orbit $sSAT$slave.LED tmp 2.
mv tmp $sSAT$slave.LED
#
# record the polorization
# set pol = \`echo $i | awk '{if (\$1 <= 4) print "VH"; else print "VV"}'\`
#\touch ../\$pol
endif
endif
# calculate baseline
#SAT_baseline \`\ls *${master}_ALL*.PRM | awk 'NR==1 {print $1}'\` \`\ls *${slave}_ALL*.PRM | awk 'NR==1 {print $1}'\` > ! baseline_info.dat
# go up
cd ${workdir}/${insar_dir}/${f}/F${i}
# calculate the interferogram
p2p_S1A_SLC_multi.csh ${mSAT}${master} ${sSAT}${slave} ${workdir}/${config_file}
son
  else if ($sensor == "SENTINEL" && $mode == "iw") then
  # preproc_batch_tops.csh gives swaths from 1 to 3 only. So if VV bands are used put the files in F4 to F6
   if ($i > 3) then
    @ swno = $i - 3
   endif
  cat <<son> ! ${master}_${slave}_F${i}_int.sh 
#!/bin/csh -f
if ($proc_stage == 1) then
# skip  align_tops.csh if the scrip has been run before
if (! -e ${workdir}/${insar_dir}/${f}/F${i}/raw/${mSAT}${master}_ALL_F${swno}.PRM || ! -e ${workdir}/${insar_dir}/${f}/F${i}/raw/${sSAT}${slave}_ALL_F${swno}.PRM || ! -e ${workdir}/${insar_dir}/${f}/F${i}/raw/${mSAT}${master}_ALL_F${swno}.SLC || ! -e ${workdir}/${insar_dir}/${f}/F${i}/raw/${sSAT}${slave}_ALL_F${swno}.SLC) then
# go to processing folder
cd ${workdir}/${insar_dir}/${f}/${proc}
# list frames incase there is more than one frame so that they can be stiched.
echo $xM:t:r | awk '{for (i=1; i <= NF; i++) printf"%s:", \$i }' > ! frames.in
echo $orbM >> frames.in
echo $xS:t:r | awk '{for (i=1; i <= NF; i++) printf"%s:", \$i }' >>  frames.in
echo $orbS >> frames.in
# record the polorization
# set pol = \`echo $i | awk '{if (\$1 <= 4) print "VH"; else print "VV"}'\`
#\touch ../\$pol
# stich and align
preproc_batch_tops.csh frames.in $workdir/topo/dem.grd 2
# link the files
ln -sf ${workdir}/${insar_dir}/${f}/${proc}/*_F${swno}* ${workdir}/${insar_dir}/${f}/F${i}/raw/
endif
endif
# calculate baseline
#SAT_baseline \`\ls *${master}_ALL*.PRM | awk 'NR==1 {print $1}'\` \`\ls *${slave}_ALL*.PRM | awk 'NR==1 {print $1}'\` > ! baseline_info.dat
# go up
cd ${workdir}/${insar_dir}/${f}/F${i}
# calculate the interferogram
p2p_S1A_TOPS_multi.csh ${mSAT}${master}_ALL_F${swno} ${sSAT}${slave}_ALL_F${swno} ${workdir}/${config_file}
son
  cat <<son> ! ${master}_${slave}_F${i}_pre.sh 
#!/bin/csh -f
if ($proc_stage == 1) then
# skip  align_tops.csh if the scrip is reruning
if (! -e ${workdir}/${insar_dir}/${f}/F${i}/raw/${mSAT}${master}_ALL_F${swno}.PRM || ! -e ${workdir}/${insar_dir}/${f}/F${i}/raw/${sSAT}${slave}_ALL_F${swno}.PRM || ! -e ${workdir}/${insar_dir}/${f}/F${i}/raw/${mSAT}${master}_ALL_F${swno}.SLC || ! -e ${workdir}/${insar_dir}/${f}/F${i}/raw/${sSAT}${slave}_ALL_F${swno}.SLC) then
# go to processing folder
cd ${workdir}/${insar_dir}/${f}/${proc}
# list frames incase there is more than one frame so that they can be stiched.
echo $xM:t:r | awk '{for (i=1; i <= NF; i++) printf"%s:", \$i }' > ! frames.in
echo $orbM >> frames.in
echo $xS:t:r | awk '{for (i=1; i <= NF; i++) printf"%s:", \$i }' >>  frames.in
echo $orbS >> frames.in
# record the polorization
# set pol = \`echo $i | awk '{if (\$1 <= 4) print "VH"; else print "VV"}'\`
#\touch ../\$pol
# stich and align
preproc_batch_tops.csh frames.in $workdir/topo/dem.grd 2
# link the files
ln -sf ${workdir}/${insar_dir}/${f}/${proc}/*_F${swno}* ${workdir}/${insar_dir}/${f}/F${i}/raw/
endif
endif
# calculate baseline
#SAT_baseline \`\ls *${master}_ALL*.PRM | awk 'NR==1 {print $1}'\` \`\ls *${slave}_ALL*.PRM | awk 'NR==1 {print $1}'\` > ! baseline_info.dat
son
############################## merge #########################################################
#if ( $merge_swaths == 1) then
cat <<son> ! ${master}_${slave}_merge.sh 
#!/bin/csh -f
# go to interero folder
cd ${workdir}/${insar_dir}/${f}
# make merge folder
if (-e F_all) then
 \rm -r F_all
endif
mkdir F_all;cd F_all
ln -s ${workdir}/topo/dem.grd .

# form the list
if ($PS == "SM") then
 find ${workdir}/${insar_dir}/${f} -name \*ALL\*PRM | grep intf | grep -v ${mSAT}${master}      | sort | awk -F"/" '{printf \$NF" "; \$NF="";OFS="/"; print \$0}' | awk '{if (NR==1) printf \$2":"\$1; else printf ","\$2":"\$1}' > ! merge.list
else
 find \`\\ls -d ${workdir}/${insar_dir}/${supermaster}* | awk 'NR==1 {print \$0}'\`   -name \*ALL\*PRM | grep intf | grep -v ${mSAT}${supermaster} | sort | awk -F"/" '{printf \$NF" "; \$NF="";OFS="/"; print \$0}' | awk '{if (NR==1) printf \$2":"\$1; else printf ","\$2":"\$1}' > ! merge.list
 find ${workdir}/${insar_dir}/${f} -name \*ALL\*PRM | grep intf | grep -v ${mSAT}${master}      | sort | awk -F"/" '{printf \$NF" "; \$NF="";OFS="/"; print \$0}' | awk '{if (NR==1) printf \$2":"\$1; else printf ","\$2":"\$1}' >> merge.list
endif
# merge
merge_batch_multi.csh merge.list ${workdir}/$config_file
son
#endif

endif # end of sensors
##################################################################################
   # make sure p2p script is created
##################################################################################
 if ($sensor == "SENTINEL" && $mode == "iw") then
  if (! -e ${master}_${slave}_F${i}_int.sh || ! -e ${master}_${slave}_F${i}_pre.sh) then
    echo ""
    echo " ERROR\! no processing script is created"
    echo " check format, mode or level"
    echo ""
    set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
    kill $PPID
    exit 1
   endif 
   #make the file executable
    chmod +x ${master}_${slave}*.sh   
    #echo  "ready to run the interfero script below"
    #echo  "${master}_${slave}_F${i}.sh"
    #
  else
   if (! -e ${master}_${slave}_F${i}.sh) then
    echo ""
    echo " ERROR\! no processing script is created"
    echo " check format, mode or level"
    echo ""
    set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
    kill $PPID
    exit 1
   endif 
    chmod +x ${master}_${slave}_F${i}*.sh   
 endif 
    echo  "$insar_dir interferogram ${master}_${slave}_F${i} number $n out of $n_ifg"
   ######## copy scripts to queue folder   #################################################################
   if ($sensor == "SENTINEL" && $mode == "iw") then
    cp ${workdir}/${insar_dir}/${master}_${slave}/${master}_${slave}_F${i}_int.sh ${workdir}/${insar_dir}/queue/F$i/${n}_int.sh
    cp ${workdir}/${insar_dir}/${master}_${slave}/${master}_${slave}_F${i}_pre.sh ${workdir}/${insar_dir}/queue/F$i/${n}_pre.sh 
    cp ${workdir}/${insar_dir}/${master}_${slave}/${master}_${slave}_merge.sh ${workdir}/${insar_dir}/queue/${n}_merge.sh 
   else 
    cp ${workdir}/${insar_dir}/${master}_${slave}/${master}_${slave}_F${i}.sh ${workdir}/${insar_dir}/queue/F$i/${n}_int.sh
   endif   
   #######################################
   # see the tail of log
   #echo ""   
   #tail -n 3 ${master}_${slave}_F${i}.log
   #echo "" 
   # uniq interfero no 
   # @ n = $n + 1
   # subswath  number
   @ i = $i + 1
 # loop subswaths 
 end
   # same interfero no for different subswaths
   @ n = $n + 1
   # skip if master or slave image or their orbit file does not  exist
  atla:
 # to next ifg
 cd ../
 # reset the swath number for the next slave
 set i = $swathS
 # loop ifgs 
end
#######################################################################################################################
# send the jobs to queue
scripts:
if( $pre_proc == 1 | $ifg_proc == 1) then 
 echo ""
 echo " submitting jobs to partition $partition "
 echo ""
endif
sleep 10s
# loop swaths
set i =  $swathS
while ($i <= $swathE)
 if ($pre_proc == 1) then
  if ($sensor == "SENTINEL" && $mode == "iw") then
  # crop dem.grd only, no simulation. if the master changes a new dem is formed.
  if ($dem4subswath == 1) then
   # make dem for the subswath only due to memory limit
    make_dem_gmtsar.csh ${workdir}/$config_file $i
  else
   # make dem for entire frame containing all the subswaths
   make_dem_gmtsar.csh ${workdir}/$config_file 1,2,3
  endif
  # number of preprocs for array size
   set nifg = `\ls ${workdir}/${insar_dir}/queue/F$i/[1-9]*pre.sh | wc -l`
  # remove logs in case re running
  if (`find ${workdir}/${insar_dir}/queue/F$i/ -name "pre*.???" | wc -l` > 0) then
   rm ${workdir}/${insar_dir}/queue/F$i/pre*.???
  endif
  # delete empty SLC files
   if (`find ${workdir}/${insar_dir} -size 0 -print -name "*.SLC" | wc -l` > 0) then
    find ${workdir}/${insar_dir} -size 0 -print -name "*.SLC" | xargs rm
   endif  
  # counter for redoing 
  set t = 1
  redoit0:
  cd $workdir/${insar_dir}
  #
  ##  run pre procs
  set fst = 1
  set j = 1
  # loop for $core jobs at a time 
  while ($fst <= $nifg) 
   @ lst = $fst + $core - 1
   #
   if ($lst > $nifg) then
    set lst = $nifg
   endif
   ##  write the sbatch scritp for pre proc 
   cat << son > !  ${workdir}/${insar_dir}/queue/F$i/queue-${j}_pre.sh
#!/bin/bash
#SBATCH -p $partition 
#SBATCH -A $account  
#SBATCH -J ${name}_F${i}_pre_${j}
#SBATCH -N $nodes
#SBATCH -n $ntask
#SBATCH --array=${fst}-${lst}
#SBATCH --time=$time_limit 
#SBATCH --output=pre-%j.out
#SBATCH --error=pre-%j.err
csh -f $workdir/${insar_dir}/queue/F$i/\$SLURM_ARRAY_TASK_ID"_pre.sh"
son
   #
   # check the queue before sending
   check_queue.csh $name
   #
   # go to swath dir 
   cd $workdir/${insar_dir}/queue/F$i
   # 
    echo "" 
    echo  " ${name}_F${i} queue-${j}_pre.sh "
    echo ""
   # sent the job to queue
   sbatch $workdir/${insar_dir}/queue/F$i/queue-${j}_pre.sh
   #
   # check the queue and make sure all are done before the next step
   check_queue.csh $name 
   #
   cd $workdir
   # next group of pairs
   @ fst = $fst + $core
   @ j = $j + 1
  end
    # check and re calculate failed ones only once ($t = 1)
    set l = 1
    set m = 1
    set nl = 
    cd ${workdir}/${insar_dir}/queue/F${i}
    if (`grep CANCEL pre* | wc -l` > 0 ) then
     # try redoing it once
     if ($t <= 2) then
      foreach f (`grep CANCEL pre* | awk -F: '{print $1}' | awk -F. '{print $1".out"}'`)
        # get the date
        set fp = `awk -F"/" 'NR==1 {print $(NF-1)}' $f | awk -F_ '{print $2}'`
        # script name
        set sf = `\grep $fp *pre.sh | awk -F: 'NR==1{print $1}' `
        # script is found
        if ($sf != "") then
          set sfn = `echo $sf | awk -F_ ' {print $1}'` 
          # skip if the number of script is the same as $l
          if ($sfn != $l) then
          \mv $sf ${l}_pre.sh
          endif
        else
        # script is missing
         @ l --
        endif
        echo $l
        @ l ++
      end  
      # delete those already done
      foreach f ([1-9]*pre.sh )
       set ss = `echo $f | awk -F_ ' {print $1}'`
       if ($ss > $l ) then
        \rm $f
       endif
      end
      @ m = $l - 1 
      @ t ++      
      goto redoit0
     endif   
    endif
   endif 
 endif # end of $pre_proc = 1
 ##############################################################
 #   interferograms 
 #################################################
 if ($ifg_proc == 1) then
  # make make topo_ra 
  if ($PS == "SM") then
   # simulate the dem and use the output for all the pairs for SM pairs
   if ($dem4subswath == 1) then
    # make dem for the subswath only due to memory limit
     make_dem_gmtsar.csh ${workdir}/$config_file $i 1
   else
    # make dem for the entire frame containing all the subswaths
    make_dem_gmtsar.csh ${workdir}/$config_file 1,2,3 1
   endif
  else
  # if SBAS, then the dem will be simulated separately for each pair
  # so remove simulation files from the main topo directroy if they exist
  # otherwise they will be used in p2p_S1A_TOPS_multi.csh to gain time 
   if (-e ${workdir}/topo/topo_ra.grd) then
    \rm ${workdir}/topo/topo_ra.grd
    \rm ${workdir}/topo/trans.dat
   endif
  endif
  #
  # find crashed pairs and then clear the interfero script 
  #
  #foreach f (`grep CANCEL pr* | awk -F: '{print $1}' | awk -F. '{print $1".out"}'`)
  # set fp = `awk 'NR==1{ print $0}' $f | awk -F"/" 'NR==1{ print $(NF-1)}'`
  # echo " $fp failed"
  # set intf = `grep $fp *sh | awk ' NR==1 {print $1}' | awk -F: '{print $1}'`
  # echo " echo preproc of $fp failed" > ! $intf
  # echo "">> $intf
   #if (! -e ../../crashed_pairs) then
    # mkdir ../../crashed_pairs
   #endif
   #if (-e ../../$fp) then
    # do not move them to crashed_pairs folder in case other subswaths may work
    # mv ../../$fp ../../crashed_pairs
    #echo ${inf}_F${i} >>! ../../crashed_pairs.txt 
   #endif
   #end
   # counter for redoing 
  set t = 1
  redoit:
  cd $workdir/${insar_dir}
  #
  # number of preprocs for array size
  set nifg = `\ls ${workdir}/${insar_dir}/queue/F$i/[1-9]*int.sh | wc -l`
  if (`find ${workdir}/${insar_dir}/queue/F$i/ -name "int*.???" | wc -l` > 0) then
   rm ${workdir}/${insar_dir}/queue/F$i/int*.???
  endif
  ##  run interferogram
  set fst = 1
  set j = 1
  # loop for $core jobs at a time 
   while ($fst <= $nifg)  
    #if ($fst == 1 && ! -e ${workdir}/topo/topo_ra.grd) then
     # set lst = 2
    #else
    @ lst = $fst + $core - 1
    #endif
    #
    if ($lst > $nifg) then
     set lst = $nifg
     endif
    # 
    #SBATCH --mail-type=ALL
    cat <<son > !  ${workdir}/${insar_dir}/queue/F$i/queue-${j}_int.sh
#!/bin/bash
#SBATCH -p $partition 
#SBATCH -A $account  
#SBATCH -J ${name}_F${i}_int_${j}
#SBATCH -N $nodes
#SBATCH -n $ntask
#SBATCH --array=${fst}-${lst}
#SBATCH --time=$time_limit
#SBATCH --output=int-%j.out
#SBATCH --error=int-%j.err
csh -f $workdir/${insar_dir}/queue/F$i/\$SLURM_ARRAY_TASK_ID"_int.sh"
son
    #  
    # check the queue before sending
     check_queue.csh  $name 
    #
    # go to swath dir 
    cd $workdir/${insar_dir}/queue/F$i
    #
    # sent the job to queue
    echo "" 
    echo  " ${name}_F${i} queue-${j}_int.sh "
    echo ""
    sbatch $workdir/${insar_dir}/queue/F$i/queue-${j}_int.sh
    #
    ########################################
    # check the queue and make sure all are done
    check_queue.csh  $name 
    cd $workdir
     @ fst = $fst + $core
     @ j = $j + 1
   end
    # check and re calculate failed ones only once ($t = 1)
    set l = 1
    set m = 1
    set nl = 
    cd ${workdir}/${insar_dir}/queue/F${i}/
    if (`grep CANCEL int* | wc -l` > 0 ) then
     # try doing it twice
     if ($t <= 2) then
      foreach f (`grep CANCEL int* | awk -F: '{print $1}' | awk -F. '{print $1".out"}'`)
        # get the date
        set fp = `awk -F"/" 'NR==1 {print $(NF-1)}' $f | awk -F_ '{print $2}'`
        # script name
        set sf = `\grep $fp *int.sh | awk -F: 'NR==1{print $1}' `
        # script is found
        if ($sf != "") then
          set sfn = `echo $sf | awk -F_ ' {print $1}'` 
          # skip if the number of script is the same as $l
          if ($sfn != $l) then
          \mv $sf ${l}_int.sh
          endif
        else
        # script is missing
         @ l --
        endif
        echo $l
        @ l ++
      end  
      # delete those already done
      foreach f ([1-9]*int.sh )
       set ss = `echo $f | awk -F_ ' {print $1}'`
       if ($ss > $l ) then
        \rm $f
       endif
      end
      @ m = $l - 1 
      @ t ++      
      goto redoit
     endif   
    endif
 endif
 @ i = $i + 1
end # loop subswaths
################################################################################
# merge subswaths
################################################################################
# 
if ($sensor == "SENTINEL" && $mode == "iw") then
 if ( $merge_proc == 1) then 
  if ( $merge_swaths == 1) then
   echo ""
   echo " merging subswaths "
   echo ""
   sleep 10s
   # number of preprocs for array size
   set nifg = `\ls ${workdir}/${insar_dir}/queue/[1-9]*merge.sh | wc -l`
   #
   ##  run pre procs
   set fst = 1
   set j = 1
   # loop for $core jobs at a time 
   while ($fst <= $nifg) 
    @ lst = $fst + $core - 1
    #
    if ($lst > $nifg) then
     set lst = $nifg
    endif
    ##  write the sbatch scritp for pre proc 
   cat << son > !  ${workdir}/${insar_dir}/queue/queue-${j}_merge.sh
#!/bin/bash
#SBATCH -p $partition 
#SBATCH -A $account  
#SBATCH -J ${name}_merge_${j}
#SBATCH -N $nodes
#SBATCH -n $ntask
#SBATCH --array=${fst}-${lst}
#SBATCH --time=$time_limit 
#SBATCH --output=merge-%j.out
#SBATCH --error=merge-%j.err
csh -f $workdir/${insar_dir}/queue/\$SLURM_ARRAY_TASK_ID"_merge.sh"
son
    #
    # check the queue before sending
    check_queue.csh $name
    #
    # go queue dir 
    cd $workdir/${insar_dir}/queue
    # 
    echo "" 
    echo  " ${name}_F${i} queue-${j}_merge.sh "
    echo ""
    # sent the job to queue
    sbatch $workdir/${insar_dir}/queue/queue-${j}_merge.sh
    #
    # check the queue and make sure all are done before the next step
    check_queue.csh $name 
    #
    cd $workdir
    # next group of pairs
    @ fst = $fst + $core
    @ j = $j + 1
   end
  endif
 endif
endif


