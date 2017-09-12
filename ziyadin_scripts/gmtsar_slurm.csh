#!/bin/csh -f


if ($#argv < 2) then
 echo ""
 echo " give config_file start and stop steps "
 echo ""
 echo " e.g. $0  config.T43 1 6"
 echo " e.g. $0  config.T43 1"
 echo " e.g  $0  config.T432 3"
 echo ""
 echo " step 1 : unzip sentinel data with or without zip extension"
 echo " step 2 : link images"
 echo " step 3 : crop a dem for Sentinel data and plot swaths"
 echo " step 4 : make a baseline table and plot it"
 echo " step 5 : calculate interferograms"
 echo " step 6 : plot phase defined with region_cut [phasefilt_cut.png]"
 echo ""
 exit 1
endif

if ( `echo $cwd | awk -F"/" '{print $NF}' | grep T ` == "" ) then 
  echo ""
  echo " run the scrip in work directory, e.g. T43"
  echo ""
  exit 1
endif
#set config_file = `echo $cwd | awk -F"/" ' {print "config."$NF}'`
set config_file = $1
set sstart = $2
set sstop = $3
if ($3 == "") then
 set sstop = $2
endif

if (! -e $config_file) then
 echo "$config_file  does not exist"
endif


set swathS = `grep "swathS = " $config_file | awk '$1 !~/#/ {if ($2 = "=" && $1 == "swathS") print $0}' | awk 'END {print $3}' `
set swathE = `grep "swathE = " $config_file | awk '$1 !~/#/ {if ($2 = "=" && $1 == "swathE") print $0}' | awk 'END {print $3}' `
set master = `grep "master = " $config_file  | awk '$1 !~/#/ {if ($2 = "=" && $3  > 1000 && $1 == "master") print $0}'| awk ' END {print $3}' `
set region_cut =  `grep region_cut $config_file | awk '$1 !~/#/ {if ($2 = "=" && $1 == "region_cut") print $0}' | awk 'END {print $3}' `

set insar_dir = PSI_$master

if ($sstart >= 1 && $sstop <= 8) then 
 goto step$sstart
 else 
 echo " check stamps_start and/or stamps_stop"
 exit 1
endif
################################### get and unzip sentinel data ##########################################
step1:
#
# dhusget_zc.sh downloads Sentinel data but, zip extion is missing
# download SLC IW data on track 94 to KAFDAF directory after 2015-01-01  
# if no directory is (-v) given images are downloded to T94 under the current directory
# if no track (-j) is given all the tracks covering the region 35.6453,40.068:35.6455,41.500  will be downloaed
# dhusget_zc.sh -d https://scihub.copernicus.eu/dhus  -u cakir -p 'xvasdfsdf'  \
# -c 35.6453,40.068:35.6455,41.500 -T SLC -o product -s IW  -j 94 -v  KAFDAF   -t 2015-01-01
#
# download SLC IW data on track 94 to KAFDAF directory between 2015-01-01 and 2016-01-01  
# dhusget_zc.sh -d https://scihub.copernicus.eu/dhus  -u cakir -p 'xvasdfsdf'  \
# -c 35.6453,40.068:35.6455,41.500 -T SLC -o product -s IW  -j 94 -v  KAFDAF   -z 2015-01-01:2016-01-01
#
# get the date of last image downloaded and download data starting from a day before the last image's date
# download resumes if the download is not completed.
# set lastD =  `\ls KAFDAF/T94| awk -F_ '{print substr($7,1,4)"-" substr ( $7,5,2 ) "-" substr($7,7,2)}' | sort | awk 'END {print}'`
# set sdate = `date -d "$lastD - 1 day" --rfc-3339=date`
# dhusget_zc.sh -d https://scihub.copernicus.eu/dhus  -u cakir -p 'xvasdfsdf'  \
# -c 35.6453,40.068:35.6455,41.500 -T SLC -o product -s IW  -j 94 -v  KAFDAF   -t $sdate 

#
# unzip sentinel image with or without zip extension
echo " unzipping files"
sleep 5s
unzip_sentinel.csh $config_file
if ($sstop == 1) then 
 exit 1
endif
################################# make workdir and link data #####################################
step2:
echo " linking files"
sleep 5s
# link images under the  SLC directory in the workdir
link_sar_data.csh $config_file
if ($sstop == 2) then 
 exit 1
endif

################################# makedem #########################################################
step3:
echo " cropping dem"
sleep 5s
# make dem for Sentinel and TSX
# dem that covers swath 1 only  
# make_dem_gmtsar.csh  $config_file 1
# dem that contains all the subswaths of Sentinel
 make_dem_gmtsar.csh  $config_file 1,2,3

if ($sstop == 3) then 
 exit 1
endif
########################## calc &| plot baselines  #################################
step4:
echo " get and plot baselines"
sleep 5s
#  
# calc_plot_baselines.csh $config_file [1 = baseline calculation & plot baselines; 2 = plot only]
# under SLC/baselines folder
# this will create make_sb_ifg.list for SBAS and make_ifg.list for Single Master in the  SLC/baselines directory. 
# they will be copied to the workdir and used for processing. 
# to re run with different spatial and temporal baselines without baseline calculations use flag 2
# e.g. calc_plot_top_baselines.csh config.T43 2
calc_plot_top_baselines.csh   $config_file 
#
if ($sstop == 4) then 
 exit 1
endif

########################## calculate interferograms   #################################
step5:
# gmtsar_slurm.csh $config_file [1|0 for write scripts, 1|0 for run pre proc, 1|0 for make inteferos;  1|0 for run merge]
# 1 = yes, 0 = no
#
# write scripts only
# gmtsar_slurm.csh  $config_file 1 
#
# run preproc and interfero scripts
# gmtsar_slurm.csh  $config_file 0 1 1
#
# write the scripts and send all to the queue 
# p2p_all.csh  $config_file 1 1 1 1
# or
p2p_all.csh  $config_file

if ($sstop == 5) then 
 exit 1
endif

#################################
step6:
# plot and see ifgs or amplitutes for a different region_cut & delete bad ones
# plot_phase_cut.csh $insar_dir $stamps_swath $region_cut display_amp.grd
# this needs to be improved so that geocoded files can be plotted as well
plot_phase_amp_cut.csh  $insar_dir $stamps_swath $region_cut phase.grd
if ($sstop == 6) then 
 exit 1
endif


