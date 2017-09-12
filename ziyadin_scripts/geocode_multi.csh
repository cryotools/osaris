#!/bin/csh -f
#       $Id$
#
#  D. Sandwell FEB 10 2010
#  Kurt Feigl 20150811 add annotation to grd files
#  Z. Cakir 20160409 add options to chose what to geocode 
#
alias rm 'rm -f'
unset noclobber
#
  if ($#argv < 2) then
errormessage:
    echo ""
    echo "Usage: geocode.csh correlation_threshold config_file"
    echo ""
    echo " phase is masked when correlation is less than correlation_threshold"
    echo ""
    echo "Example: geocode.csh .12 config_s1a.gmtsar"
    echo ""
    exit 1
  endif
#
set config_file = $2
#
set corr_ll = `grep corr_ll $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}'| awk ' END {print $3}'`     
set phase_ll = `grep  phase_ll  $config_file  | awk '$1 !~/#/ {if ($2 = "=") print $0}'| awk ' END {print $3}'`   
set phasefilt_ll = `grep  phasefilt_ll  $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}'| awk ' END {print $3}'` 
set phase_mask_ll =  `grep   phase_mask_ll  $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}'| awk ' END {print $3}'` 
set display_amp_ll =  `grep display_amp_ll $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}'| awk ' END {print $3}'` 
set unwrap_mask_ll  =  `grep unwrap_mask_ll $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}'| awk ' END {print $3}'` 
set unwrap_ll    =  `grep     unwrap_ll  $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}'| awk ' END {print $3}'` 
set phasefilt_mask_ll  =  `grep phasefilt_mask_ll $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}'| awk ' END {print $3}'` 
set xphase_mask_ll  =  `grep xphase_mask_ll $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}'| awk ' END {print $3}'` 
set yphase_mask_ll  =  `grep yphase_mask_ll $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}'| awk ' END {print $3}'` 

set region_cut_geo  = `grep region_cut_geo $config_file| awk '$1 !~/#/ { if ($2 = "=") print $3}'| awk ' END {print $0}'`

# check if any file is set for geocoding
set nc = `grep "_ll " $config_file`
 if ($#nc < 1) then
 echo ""
 echo " nothing will be geocoded\! check out the geocoding section of $config_file "
 echo ""
 goto hata
 else
 grep "_ll " $config_file | awk 'BEGIN {print "files to be geocoded:"} {if ($3 == 1) print $1}'
endif



#
#   first mask the phase and phase gradient using the correlation
#
echo ""
echo "making mask using correlation"
echo ""
gmt grdmath corr.grd $1 GE 0 NAN mask.grd MUL = mask2.grd -V
gmt grdmath phase.grd mask2.grd MUL = phase_mask.grd
if (-e xphase.grd) then
  gmt grdmath xphase.grd mask2.grd MUL = xphase_mask.grd
  gmt grdmath yphase.grd mask2.grd MUL = yphase_mask.grd
endif
if (-e unwrap.grd) then 
  gmt grdcut mask2.grd `gmt grdinfo unwrap.grd -I-` -Gmask3.grd
  gmt grdmath unwrap.grd mask3.grd MUL = unwrap_mask.grd
endif
if (-e phasefilt.grd) then 
  gmt grdmath phasefilt.grd mask2.grd MUL = phasefilt_mask.grd
endif

#
#   look at the masked phase
#


if (-e display_amp.grd) then
 set boundR = `gmt grdinfo display_amp.grd -C | awk '{print ($3-$2)/4}'`
 set boundA = `gmt grdinfo display_amp.grd -C | awk '{print ($5-$4)/4}'`
 gmt grdimage phase_mask.grd -JX6.5i -Cphase.cpt -B"$boundR":Range:/"$boundA":Azimuth:WSen -X1.3i -Y3i -P -K > phase_mask.ps
 gmt psscale -D3.3/-1.5/5/0.2h -Cphase.cpt -B1.57:"phase, rad": -O >> phase_mask.ps
endif

if (-e xphase_mask.grd) then
  gmt grdimage xphase_mask.grd -JX8i -Cphase_grad.cpt -X.2i -Y.5i -P > xphase_mask.ps
  gmt grdimage yphase_mask.grd -JX8i -Cphase_grad.cpt -X.2i -Y.5i -P > yphase_mask.ps
endif
if (-e unwrap_mask.grd) then 
  gmt grdimage unwrap_mask.grd -JX6.5i -B"$boundR":Range:/"$boundA":Azimuth:WSen -Cunwrap.cpt -X1.3i -Y3i -P -K > unwrap_mask.ps
  set std = `gmt grdinfo -C -L2 unwrap_mask.grd | awk '{printf("%5.1f", $13)}'`
  gmt psscale -D3.3/-1.5/5/0.2h -Cunwrap.cpt -B"$std":"unwrapped phase, rad": -O -E >> unwrap_mask.ps
endif
if (-e phasefilt_mask.grd) then 
  gmt grdimage phasefilt_mask.grd -JX6.5i -B"$boundR":Range:/"$boundA":Azimuth:WSen -Cphase.cpt -X1.3i -Y3i -P -K > phasefilt_mask.ps
  gmt psscale -D3.3/-1.5/5/0.2h -Cphase.cpt -B1.57:"phase, rad": -O >> phasefilt_mask.ps
endif
# line-of-sight displacement
if (-e unwrap_mask.grd) then
  set wavel = `grep wavelength *.PRM | awk '{print($3)}' | head -1 `
  gmt grdmath unwrap_mask.grd $wavel MUL -79.58 MUL = los.grd
  gmt grdgradient los.grd -Nt.9 -A0. -Glos_grad.grd
  set tmp = `gmt grdinfo -C -L2 los.grd`
  set limitU = `echo $tmp | awk '{printf("%5.1f", $12+$13*2)}'`
  set limitL = `echo $tmp | awk '{printf("%5.1f", $12-$13*2)}'`
  set std = `echo $tmp | awk '{printf("%5.1f", $13)}'`
  gmt makecpt -Cpolar -Z -T"$limitL"/"$limitU"/1 -D > los.cpt
  gmt grdimage los.grd -Ilos_grad.grd -Clos.cpt -B"$boundR":Range:/"$boundA":Azimuth:WSen -JX6.5i -X1.3i -Y3i -P -K > los.ps
  gmt psscale -D3.3/-1.5/4/0.2h -Clos.cpt -B"$std":"LOS displacement, mm":/:"range decrease": -O -E >> los.ps 
endif

#
#  now reproject the phase to lon/lat space
#
echo "geocode.csh"
#echo "project correlation, phase, unwrapped and amplitude back to lon lat coordinates"
set maker = $0:t
set today = `date`
set remarked = `echo by $USER on $today with $maker`
echo remarked is $remarked



if ($corr_ll == 1 ) then
  echo ""
  echo "geocoding corr.grd"
   echo ""
 proj_ra2ll.csh trans.dat corr.grd        corr_ll.grd           ; gmt grdedit -D//"dimensionless"/1///"$PWD:t geocoded correlation"/"$remarked"      corr_ll.grd
endif
if ($phase_ll == 1 ) then
  echo ""
  echo "geocoding phase.grd"
  echo ""
proj_ra2ll.csh trans.dat phase.grd       phase_ll.grd          ; gmt grdedit -D//"radians"/1///"$PWD:t wrapped phase"/"$remarked"                   phase_ll.grd
endif
if ($phasefilt_ll == 1 ) then
  echo ""
  echo "geocoding phasefilt.grd"
  echo ""
 proj_ra2ll.csh trans.dat phasefilt.grd   phasefilt_ll.grd      ; gmt grdedit -D//"radians"/1///"$PWD:t wrapped phase after filtering"/"$remarked"   phasefilt_ll.grd
endif
if ($phase_mask_ll == 1 ) then
  echo ""
  echo "geocoding phase_mask.grd"
  echo ""
 proj_ra2ll.csh trans.dat phase_mask.grd  phase_mask_ll.grd     ; gmt grdedit -D//"radians"/1///"$PWD:t wrapped phase after masking"/"$remarked"     phase_mask_ll.grd
endif
if ($display_amp_ll == 1 ) then
  echo ""
  echo "geocoding display_amp.grd"
  echo ""
 proj_ra2ll.csh trans.dat display_amp.grd display_amp_ll.grd    ; gmt grdedit -D//"dimensionless"/1///"PWD:t amplitude"/"$remarked"     display_amp_ll.grd
endif

if (-e xphase_mask.grd) then
 if ($xphase_mask_ll == 1 ) then 
  echo ""
  echo "geocoding xphase_mask.grd "
  echo ""
  proj_ra2ll.csh trans.dat xphase_mask.grd xphase_mask_ll.grd  ; gmt grdedit -D//"radians"/1///"PWD:t xphase"/"$remarked"  xphase_mask_ll.grd
 endif
endif

if (-e yphase_mask.grd) then
 if ($yphase_mask_ll == 1 ) then 
  echo ""
  echo "geocoding  yphase_mask.grd"
  echo ""
  proj_ra2ll.csh trans.dat yphase_mask.grd yphase_mask_ll.grd  ; gmt grdedit -D//"radians"/1///"PWD:t yphase"/"$remarked"     yphase_mask_ll.grd
 endif
endif

if (-e unwrap_mask.grd) then
 if ($unwrap_mask_ll == 1 ) then 
  echo ""
  echo "geocoding unwrap_mask.grd"
  echo ""
  proj_ra2ll.csh trans.dat unwrap_mask.grd unwrap_mask_ll.grd  ; gmt grdedit -D//"radians"/1///"PWD:t unwrapped, masked phase"/"$remarked"    unwrap_mask_ll.grd
 endif
endif
if (-e unwrap.grd) then
 if ($unwrap_ll == 1 ) then 
  echo ""
  echo "geocoding unwrap.grd"
  echo ""
  proj_ra2ll.csh trans.dat unwrap.grd unwrap_ll.grd  ; gmt grdedit -D//"radians"/1///"PWD:t unwrapped phase"/"$remarked"               unwrap_ll.grd
 endif
endif
if (-e phasefilt_mask.grd) then
 if ($phasefilt_mask_ll == 1 ) then 
  echo ""
  echo "geocoding phasefilt_mask"
  echo ""
  proj_ra2ll.csh trans.dat phasefilt_mask.grd phasefilt_mask_ll.grd ; gmt grdedit -D//"phase in radians"/1///"PWD:t wrapped phase masked filtered"/"$remarked"   phasefilt_mask_ll.grd
 endif
endif


#
#   now image for google earth
#
echo "geocode.csh"
echo "make the KML files for Google Earth"

if (-e  display_amp_ll.grd) then
 if ($region_cut_geo != "") then
  ln -s display_amp_ll.grd display_amp_cut_ll.grd
  grd2kml.csh display_amp_cut_ll phase.cpt -R$region_cut_geo
 endif
  grd2kml.csh display_amp_ll display_amp.cpt
endif

if (-e  corr_ll.grd) then
 if ($region_cut_geo != "") then
  ln -s corr_ll.grd corr_cut_ll.grd
  grd2kml.csh corr_cut_ll phase.cpt -R$region_cut_geo
 endif
  grd2kml.csh corr_ll corr.cpt
endif

#grd2kml.csh phase_mask_ll phase.cpt
#ln -s phasefilt_mask_ll.grd phase_mask_ll_bw.grd
#grd2kml.csh phase_mask_ll_bw phase_bw.cpt
#rm phase_mask_ll_bw.grd
if (-e xphase_mask_ll.grd) then
 if ($region_cut_geo != "") then
  ln -s xphase_mask_ll.grd xphase_mask_cut_ll.grd 
  ln -s yphase_mask_ll.grd yphase_mask_cut_ll.grd 
  grd2kml.csh xphase_mask_cut_ll phase_grad.cpt -R$region_cut_geo
  grd2kml.csh yphase_mask_cut_ll phase_grad.cpt -R$region_cut_geo
 endif
  grd2kml.csh xphase_mask_ll phase_grad.cpt
  grd2kml.csh yphase_mask_ll phase_grad.cpt
endif
if (-e unwrap_mask_ll.grd) then
  # constant is negative to make LOS = -1 * range change
  # constant is (1000 mm) / (4 * pi)
   gmt grdmath unwrap_mask_ll.grd $wavel MUL -79.58 MUL = los_ll.grd 
   gmt grdedit -D//"mm"/1///"$PWD:t LOS displacement"/"equals negative range" los_ll.grd 
 if ($region_cut_geo != "") then
   ln -s  unwrap_mask_ll.grd  unwrap_mask_cut_ll.grd
   ln -s los_ll.grd los_cut_ll.grd 
   grd2kml.csh unwrap_mask_cut_ll unwrap.cpt
   grd2kml.csh los_cut_ll los.cpt -R$region_cut_geo
  endif
  grd2kml.csh los_ll los.cpt
  grd2kml.csh los_cut_ll los.cpt -R$region_cut_geo
endif

if (-e unwrap_ll.grd) then
 if ($region_cut_geo != "") then
  ln -s unwrap_ll.grd unwrap_cut_ll.grd
  grd2kml.csh unwrap_cut_ll unwrap.cpt
 endif
  grd2kml.csh unwrap_ll unwrap.cpt
endif

if (-e phasefilt_mask_ll.grd) then
 if ($region_cut_geo != "") then
  ln -s phasefilt_mask_ll.grd phasefilt_mask_cut_ll.grd
  grd2kml.csh phasefilt_mask_cut_ll phase.cpt -R$region_cut_geo
 endif
 grd2kml.csh phasefilt_mask_ll phase.cpt
endif

if (-e phase_ll.grd) then
 if ($region_cut_geo != "") then
   ln -s phase_ll.grd phase_cut_ll.grd
   grd2kml.csh phase_cut_ll phase.cpt -R$region_cut_geo
 endif
  grd2kml.csh phase_ll phase.cpt
endif

if (-e phasefilt_ll.grd) then
 if ($region_cut_geo != "") then
   ln -s  phasefilt_ll.grd  phasefilt_cut_ll.grd
   grd2kml.csh phasefilt_cut_ll phase.cpt -R$region_cut_geo
 endif
  grd2kml.csh phasefilt_ll phase.cpt
endif
rm -f *cut_ll.grd
hata:
