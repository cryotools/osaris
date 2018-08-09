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
    echo "Usage: geocode.csh correlation_threshold"
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
#  now reproject the phase to lon/lat space
#
echo "geocode.csh"
echo "project correlation, phase, unwrapped and amplitude back to lon lat coordinates"
set maker = $0:t
set today = `date`
set remarked = `echo by $USER on $today with $maker`
echo remarked is $remarked

 proj_ra2ll.csh trans.dat corr.grd        corr_ll.grd           ; gmt grdedit -D//"dimensionless"/1///"$PWD:t geocoded correlation"/"$remarked"      corr_ll.grd
#proj_ra2ll.csh trans.dat phase.grd       phase_ll.grd          ; gmt grdedit -D//"radians"/1///"$PWD:t wrapped phase"/"$remarked"                   phase_ll.grd
 proj_ra2ll.csh trans.dat phasefilt.grd   phasefilt_ll.grd      ; gmt grdedit -D//"radians"/1///"$PWD:t wrapped phase after filtering"/"$remarked"   phasefilt_ll.grd
proj_ra2ll.csh trans.dat phase_mask.grd  phase_mask_ll.grd     ; gmt grdedit -D//"radians"/1///"$PWD:t wrapped phase after masking"/"$remarked"     phase_mask_ll.grd
 proj_ra2ll.csh trans.dat display_amp.grd display_amp_ll.grd    ; gmt grdedit -D//"dimensionless"/1///"PWD:t amplitude"/"$remarked"                  display_amp_ll.grd
if (-e xphase_mask.grd) then
  proj_ra2ll.csh trans.dat xphase_mask.grd xphase_mask_ll.grd  ; gmt grdedit -D//"radians"/1///PWD:t xphase"/"$remarked"                            xphase_mask_ll.grd
  proj_ra2ll.csh trans.dat yphase_mask.grd yphase_mask_ll.grd  ; gmt grdedit -D//"radians"/1///PWD:t yphase"/"$remarked"                            yphase_mask_ll.grd
endif
if (-e unwrap_mask.grd) then
  proj_ra2ll.csh trans.dat unwrap_mask.grd unwrap_mask_ll.grd  ; gmt grdedit -D//"radians"/1///"PWD:t unwrapped, masked phase"/"$remarked"               unwrap_mask_ll.grd
endif
if (-e unwrap.grd) then
  proj_ra2ll.csh trans.dat unwrap.grd unwrap_ll.grd  ; gmt grdedit -D//"radians"/1///"PWD:t unwrapped phase"/"$remarked"               unwrap_ll.grd
endif
if (-e phasefilt_mask.grd) then
  proj_ra2ll.csh trans.dat phasefilt_mask.grd phasefilt_mask_ll.grd ; gmt grdedit -D//"phase in radians"/1///"PWD:t wrapped phase masked filtered"/"$remarked"   phasefilt_mask_ll.grd
endif
if (-e con_comp.grd) then
  proj_ra2ll.csh trans.dat con_comp.grd con_comp_ll.grd  ; gmt grdedit -D//"dimensionless"/1///"PWD:t connected components"/"$remarked" con_comp_ll.grd
endif
