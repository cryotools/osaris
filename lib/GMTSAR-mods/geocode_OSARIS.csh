#!/bin/csh -f
#       $Id$
#
#  D. Sandwell FEB 10 2010
#  Kurt Feigl 20150811 add annotation to grd files
#
alias rm 'rm -f'
unset noclobber
#
  if ($#argv < 1) then
errormessage:
    echo ""
    echo "Usage: geocode.csh correlation_threshold region_cut cut_to_aoi"
    echo ""
    echo " phase is masked when correlation is less than correlation_threshold"
    echo ""
    echo "Example: geocode.csh .12"
    echo ""
    exit 1
  endif
#
#   first mask the phase and phase gradient using the correlation
#

set cut_to_aoi = $3

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


if (-e $2) then
    set lon_1 = `awk 'NR==1{ print $1 }' $2`
    set lon_2 = `awk 'NR==2{ print $1 }' $2`
    set lat_1 = `awk 'NR==1{ print $2 }' $2`
    set lat_2 = `awk 'NR==2{ print $2 }' $2`
    if (`echo "$lon_1 > $lon_2" | bc -l` == 1) then
      set lon_max = $lon_1
      set lon_min = $lon_2
    else
      set lon_max = $lon_2
      set lon_min = $lon_1
    endif
    if (`echo "$lat_1 > $lat_2" | bc -l` == 1) then
      set lat_max = $lat_1
      set lat_min = $lat_2
    else
      set lat_max = $lat_2
      set lat_min = $lat_1
    endif
    
    set cut_coords = $lon_min"/"$lon_max"/"$lat_min"/"$lat_max
endif 

#
#  now reproject the phase to lon/lat space
#
echo "geocode.csh"
echo "project correlation, phase, unwrapped and amplitude back to lon lat coordinates"
set maker = $0:t
set today = `date`
set remarked = `echo by $USER on $today with $maker`
echo remarked is $remarked

echo; echo "Projecting coherence to geographic coordinates"
proj_ra2ll.csh trans.dat corr.grd        corr_ll.grd           
if ($cut_to_aoi == 1) then
  gmt grdcut corr_ll.grd -Gcorr_ll.grd -R$cut_coords -V
endif
gmt grdedit -D//"dimensionless"/1///"$PWD:t geocoded correlation"/"$remarked"      corr_ll.grd

# proj_ra2ll.csh trans.dat phase.grd       phase_ll.grd 
# gmt grdedit -D//"radians"/1///"$PWD:t wrapped phase"/"$remarked"                   phase_ll.grd

echo; echo "Projecting filtered phase to geographic coordinates"
proj_ra2ll.csh trans.dat phasefilt.grd   phasefilt_ll.grd
if ($cut_to_aoi == 1) then
  gmt grdcut phasefilt_ll.grd -Gphasefilt_ll.grd -R$cut_coords -V
endif
gmt grdedit -D//"radians"/1///"$PWD:t wrapped phase after filtering"/"$remarked"   phasefilt_ll.grd

echo; echo "Projecting masked phase to geographic coordinates"
proj_ra2ll.csh trans.dat phase_mask.grd  phase_mask_ll.grd
if ($cut_to_aoi == 1) then
  gmt grdcut phase_mask_ll.grd -Gphase_mask_ll.grd -R$cut_coords -V
endif
gmt grdedit -D//"radians"/1///"$PWD:t wrapped phase after masking"/"$remarked"     phase_mask_ll.grd

echo; echo "Projecting amplitude to geographic coordinates"
proj_ra2ll.csh trans.dat display_amp.grd display_amp_ll.grd
if ($cut_to_aoi == 1) then
  gmt grdcut display_amp_ll.grd -Gdisplay_amp_ll.grd -R$cut_coords -V
endif
gmt grdedit -D//"dimensionless"/1///"$PWD:t amplitude"/"$remarked"                  display_amp_ll.grd

if (-e xphase_mask.grd) then
  echo; echo "Projecting masked xphase to geographic coordinates"
  proj_ra2ll.csh trans.dat xphase_mask.grd xphase_mask_ll.grd
  if ($cut_to_aoi == 1) then
    gmt grdcut xphase_mask_ll.grd -Gxphase_mask_ll.grd -R$cut_coords -V
  endif
  gmt grdedit -D//"radians"/1///"$PWD:t xphase"/"$remarked"                          xphase_mask_ll.grd
  echo; echo "Projecting masked yphase to geographic coordinates"
  proj_ra2ll.csh trans.dat yphase_mask.grd yphase_mask_ll.grd
  if ($cut_to_aoi == 1) then
    gmt grdcut yphase_mask_ll.grd -Gyphase_mask_ll.grd -R$cut_coords -V
  endif
  gmt grdedit -D//"radians"/1///"$PWD:t yphase"/"$remarked"                          yphase_mask_ll.grd
endif

if (-e unwrap_mask.grd) then
  echo; echo "Projecting masked unwrapped phase to geographic coordinates"
  proj_ra2ll.csh trans.dat unwrap_mask.grd unwrap_mask_ll.grd 
  if ($cut_to_aoi == 1) then
    gmt grdcut unwrap_mask_ll.grd -Gunwrap_mask_ll.grd -R$cut_coords -V
  endif
  gmt grdedit -D//"radians"/1///"PWD:t unwrapped, masked phase"/"$remarked"        unwrap_mask_ll.grd
endif

if (-e unwrap.grd) then
  echo; echo "Projecting unwrapped phase to geographic coordinates"
  proj_ra2ll.csh trans.dat unwrap.grd unwrap_ll.grd
  if ($cut_to_aoi == 1) then
    gmt grdcut unwrap_ll.grd -Gunwrap_ll.grd -R$cut_coords -V
  endif
  gmt grdedit -D//"radians"/1///"PWD:t unwrapped phase"/"$remarked"               unwrap_ll.grd
endif

if (-e phasefilt_mask.grd) then
  echo; echo "Projecting filtered masked phase to geographic coordinates"
  proj_ra2ll.csh trans.dat phasefilt_mask.grd phasefilt_mask_ll.grd
  if ($cut_to_aoi == 1) then
    gmt grdcut phasefilt_mask_ll.grd -Gphasefilt_mask_ll.grd -R$cut_coords -V
  endif
  gmt grdedit -D//"phase in radians"/1///"PWD:t wrapped phase masked filtered"/"$remarked"   phasefilt_mask_ll.grd
endif

if (-e con_comp.grd) then
  echo; echo "Projecting Snaphu connected components to geographic coordinates"
  proj_ra2ll.csh trans.dat con_comp.grd con_comp_ll.grd
  if ($cut_to_aoi == 1) then
    gmt grdcut con_comp_ll.grd -Gcon_comp_ll.grd -R$cut_coords -V
  endif
  gmt grdedit -D//"dimensionless"/1///"PWD:t connected components"/"$remarked" con_comp_ll.grd
endif

