#!/bin/csh -f
####### Ziyadin April 2016 ################################################################# 
 
if ($#argv < 1) then  
  echo " "
  echo " give region [PRM file] [dem.grd]"
  echo ""
  echo " fore example"
  echo " $0 44.60/44.9/41.65/41.75  [S1A20161103_ALL_F2.PRM] [dem.grd]"
  echo ""
   echo " no PRM or dem file needed if run under interfero folder  "
 exit 1
endif
set workdir = $cwd
set region_cut_geo = $1
set PRM = $2
set dem = $3
if ($dem == "") then
 set dem  = ../../topo/dem.grd
endif

# in case it is in interfero folder get the master PRM
if ($PRM == "") then
 set doy = `echo $cwd:t | awk -F_ '{print substr($1,5,3)}'`
 set yr = `echo $cwd:t | awk -F_ '{print substr($1,1,4)}'`
 set d = `date -d "$yr-01-01 + $doy day " --rfc-3339=date | awk -F- '{print $1$2$3}'`
 set PRM = ./*$d*PRM
 endif
if ($PRM == "") then
 echo "PRM file $PRM does not exist"
 exit 1
endif

 # get  ranges
# convert to radar coordinates if  the unwrap region is given in geographic coordinates
if (-e phase.grd) then
 set file = phase.grd
else if (-e phasefilt.grd ) then
 set file = phasefilt.grd
else if (-e image.grd ) then
 set file = image.grd
endif
if (! -e $file) then
       set rmax = 10000000
       set amax = 10000000
       echo ""
       echo " phase.grd, phasefilt.grd or imag.grd does not exist to get the boundaries"
       echo " no maximum in azimuth or range is defined"
       echo " make sure $region_cut_geo is inside the radar frame"
       echo ""
else
       set rmax = `grdinfo $file -C -Vq | awk '{print $3}'`
       set amax = `grdinfo $file -C -Vq  | awk '{print $5}'`
endif
echo ""
if ($dem == "") then
      echo " dem file $dem or  ../../topo/dem.grd does not exist"
      echo " no elevation value will be used"
      echo ""  > ! region_cut    
      echo ""
      set h1 = 0
      set h2 = 0
      set h3 = 0 
      set h4 = 0
else
     # get  elevation of each corner
      set h1 = `echo $region_cut_geo | awk -F"/" '{print $1,$3}' | grdtrack -G$dem | awk '{print $3}'`
      set h2 = `echo $region_cut_geo | awk -F"/" '{print $2,$4}' | grdtrack -G$dem | awk '{print $3}'`
      set h3 = `echo $region_cut_geo | awk -F"/" '{print $1,$4}' | grdtrack -G$dem | awk '{print $3}'`
      set h4 = `echo $region_cut_geo | awk -F"/" '{print $2,$3}' | grdtrack -G$dem | awk '{print $3}'`
       if ( $h1 == "" || $h2 == ""  || $h3 == "" || $h4 == "") then
        echo "ERROR"
        echo "dem does not cover the entire region selected. Check the region_cut_geo "
        echo ""
        echo ""   > ! region_cut
        exit 1
       endif
endif
# go the folder where PRM file is since it will likely contain the LED file needed for SAT_llt2rat
# translate the geographic coordinates to the radar coordinates. 
set region_cut = `echo $region_cut_geo | awk -F"/" '{printf"%s %s %s\n %s %s %s\n %s %s %s\n %s %s %s\n", $1,$3,'$h1',$2,$4,'$h2',$1,$4,'$h3',$2,$3,'$h4'}' | SAT_llt2rat $PRM 0 | gmtinfo -C | awk '{if ($1 < 0) $1 = 0; if ($2 < 0) $2 = 0;if ($2 > '$rmax') $2 = '$rmax'; if ($1 > '$rmax') $1 = '$rmax';if ($3 < 0) $3 = 0; if ($4 < 0) $4 = 0;if ($4 > '$amax') $4 = '$amax'  ;if ($3 > '$amax') $3 = '$amax' ; print int($1)"/"int($2)"/"int($3)"/"int($4)}' `

#echo " REGION TO BE UNWRAPPED"
echo " Geographic: $region_cut_geo"
echo " Radar     : $region_cut"

echo $region_cut  > ! region_cut
 
