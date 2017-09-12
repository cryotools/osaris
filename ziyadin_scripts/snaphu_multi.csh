#!/bin/csh -f
#       $Id$
#
# Z. Cakir, July 2016, option for interpolating masked regions for quicker unwrapping
alias rm 'rm -f'
unset noclobber
#
  if ($#argv < 2) then
errormessage:
    echo ""
    echo "snaphu.csh [GMT5SAR] - Unwrap the phase"
    echo " "
    echo "Usage: snaphu.csh correlation_threshold maximum_discontinuity [<rng0>/<rngf>/<azi0>/<azif>] [1==interpolate masked regions]"
    echo ""
    echo "       correlation is reset to zero when < threshold"
    echo "       maximum_discontinuity enables phase jumps for earthquake ruptures, etc."
    echo "       set maximum_discontinuity = 0 for continuous phase such as interseismic "
    echo "       interpolate regions where correlation  < threshold"
    echo ""
    echo "Example: snaphu.csh .12 40 1000/3000/24000/27000 1"
    echo ""
    echo "Reference:"
    echo "Chen C. W. and H. A. Zebker, Network approaches to two-dimensional phase unwrapping: intractability and two new algorithms, Journal of the Optical Society of America A, vol. 17, pp. 401-414 (2000)."
    exit 1
  endif
#
# prepare the files adding the correlation mask
#
if ($#argv >= 3) then
   gmt grdcut mask.grd -R$3 -Gmask_patch.grd
   gmt grdcut corr.grd -R$3 -Gcorr_patch.grd
   gmt grdcut phasefilt.grd -R$3 -Gphase_patch.grd
else
   ln -s mask.grd mask_patch.grd
   ln -s corr.grd corr_patch.grd
   ln -s phasefilt.grd phase_patch.grd
endif
# NO NEED since the phase is already landmasked  
# create landmask
#
#if (-e landmask_ra.grd) then
 # if ($#argv >= 3 ) then 
    # in case the landmask region is smaller than the region_cut pad with NaN
    #gmt grd2xyz landmask_ra.grd -bo > landmask_ra.xyz
    #gmt xyz2grd landmask_ra.xyz -bi -r -R$3 `gmt grdinfo -I landmask_ra.grd` -Gtmp.grd 
    #mv tmp.grd landmask_ra_c.grd
    #gmt grdsample landmask_ra_c.grd -Gtmp.grd -R$3 -I4/8 -nl+t0.1
    #mv tmp.grd landmask_ra_c.grd
    # cleanup
    #rm landmask_ra.xyz
    #gmt grdsample landmask_ra_c.grd -R$3 `gmt grdinfo -I phase_patch.grd` -Glandmask_ra_patch.grd
#    gmt grdsample landmask_ra.grd -R$3 `gmt grdinfo -I phase_patch.grd` -Glandmask_ra_patch.grd
 #   grdedit  `grdinfo -Ir  phase_patch.grd`  landmask_ra_patch.grd
#  else 
#    gmt grdsample landmask_ra.grd `gmt grdinfo -I phase_patch.grd` -Glandmask_ra_patch.grd
#  endif
#  gmt grdmath phase_patch.grd landmask_ra_patch.grd MUL = phase_patch.grd -V
#endif
#
# user defined mask 
#
if (-e mask_def.grd) then
  if ($#argv >= 3 ) then
    gmt grdcut mask_def.grd -R$3 -Gmask_def_patch.grd
  else
    cp mask_def.grd mask_def_patch.grd
  endif
  gmt grdmath corr_patch.grd mask_def_patch.grd MUL = corr_patch.grd -V
endif

gmt grdmath corr_patch.grd $1 GE 0 NAN mask_patch.grd MUL = mask2_patch.grd
gmt grdmath corr_patch.grd 0. XOR 1. MIN  = corr_patch.grd
gmt grdmath mask2_patch.grd corr_patch.grd MUL = corr_tmp.grd 


# interpolate masked regions for quick unwrapping
if ($#argv == 4) then
 if ($4 == 1) then
  echo ""
  echo "interpolating the interferogram for quick unwrapping -- thanks to Eric Lindsey"
  echo ""
  gmt grdmath mask2_patch.grd phase_patch.grd MUL = phase_patch_masked.grd
  set minx = `grdinfo -C phase_patch.grd |cut -f 2`
  set maxx = `grdinfo -C phase_patch.grd |cut -f 3`
  set nx = `grdinfo -C phase_patch.grd|cut -f 10`
  set boundsx = "$minx $maxx"
  set miny = `grdinfo -C  phase_patch.grd |cut -f 4`
  set maxy = `grdinfo -C  phase_patch.grd |cut -f 5`
  set ny = `grdinfo -C phase_patch.grd  |cut -f 11`
  # for some reason we have to reverse these two!
  set boundsy = "$maxy $miny"
  # mask the interfero
  gmt grdmath mask2_patch.grd phase_patch.grd MUL = phase_patch_masked.grd
  # convert to ascii
  gmt grd2xyz phase_patch_masked.grd  -s -V > phase_patch.gmt
  # run gdal, then convert back to grd
  gdal_grid -of GTiff -txe $boundsx -tye $boundsy -outsize $nx $ny -l phase_patch -a nearest phase_patch.gmt interpolate.tiff
  gdal_translate -of GMT -ot Float32 interpolate.tiff phase_patch.grd
  # fix the grd header metadata
  gmt grdedit phase_patch.grd -T #(note: must be pixel node registration for snaphu)
  gmt grdedit phase_patch.grd -R$minx/$maxx/$miny/$maxy
  gmt grd2xyz phase_patch.grd -ZTLf -d0 > phase.in
  gmt grd2xyz corr_tmp.grd -ZTLf  -d0 > corr.in
  rm interpolate.tiff phase_patch.gmt 
 else
  echo ""
  echo "no interpolation before unwrap"
  echo ""
  gmt grd2xyz phase_patch.grd -ZTLf -d0 > phase.in
  gmt grd2xyz corr_tmp.grd -ZTLf  -d0 > corr.in
 endif
else
  gmt grd2xyz phase_patch.grd -ZTLf -d0 > phase.in
  gmt grd2xyz corr_tmp.grd -ZTLf  -d0 > corr.in
endif

#
# run snaphu
#
set sharedir = `gmtsar_sharedir.csh`
echo "unwrapping phase with snaphu - higher threshold for faster unwrapping "

if ($2 == 0) then
  snaphu phase.in `gmt grdinfo -C phase_patch.grd | cut -f 10` -f $sharedir/snaphu/config/snaphu.conf.brief -c corr.in -o unwrap.out -v -s
else
  sed "s/.*DEFOMAX_CYCLE.*/DEFOMAX_CYCLE  $2/g" $sharedir/snaphu/config/snaphu.conf.brief > snaphu.conf.brief
  snaphu phase.in `gmt grdinfo -C phase_patch.grd | cut -f 10` -f snaphu.conf.brief -c corr.in -o unwrap.out -v -d
endif
#
# convert to grd
#
gmt xyz2grd unwrap.out -ZTLf -r `gmt grdinfo -I- phase_patch.grd` `gmt grdinfo -I phase_patch.grd` -Gtmp.grd
gmt grdmath tmp.grd mask2_patch.grd MUL = tmp.grd
#
# detrend the unwrapped if DEFOMAX = 0 for interseismic
#
if ($2 == 0) then
  gmt grdtrend tmp.grd -N3r -Dunwrap.grd
else
  mv tmp.grd unwrap.grd
endif
#
# landmask
if (-e landmask_ra.grd) then
  gmt grdmath unwrap.grd landmask_ra_patch.grd MUL = tmp.grd -V
  mv tmp.grd unwrap.grd
endif
#
# user defined mask
#
if (-e mask_def.grd) then
  gmt grdmath unwrap.grd mask_def_patch.grd MUL = tmp.grd -V
  mv tmp.grd unwrap.grd
endif
#
#  plot the unwrapped phase
#
gmt grdgradient unwrap.grd -Nt.9 -A0. -Gunwrap_grad.grd
set tmp = `gmt grdinfo -C -L2 unwrap.grd`
set limitU = `echo $tmp | awk '{printf("%5.1f", $12+$13*2)}'`
set limitL = `echo $tmp | awk '{printf("%5.1f", $12-$13*2)}'`
set std = `echo $tmp | awk '{printf("%5.1f", $13)}'`
gmt makecpt -Cseis -I -Z -T"$limitL"/"$limitU"/1 -D > unwrap.cpt
set boundR = `gmt grdinfo unwrap.grd -C | awk '{print ($3-$2)/4}'`
set boundA = `gmt grdinfo unwrap.grd -C | awk '{print ($5-$4)/4}'`
gmt grdimage unwrap.grd -Iunwrap_grad.grd -Cunwrap.cpt -JX6.5i -B"$boundR":Range:/"$boundA":Azimuth:WSen -X1.3i -Y3i -P -K > unwrap.ps
gmt psscale -D3.3/-1.5/5/0.2h -Cunwrap.cpt -B"$std":"unwrapped phase, rad": -O -E >> unwrap.ps
#
# clean up
#
rm tmp.grd corr_tmp.grd unwrap.out tmp2.grd unwrap_grad.grd 
rm phase.in corr.in 
#
#   cleanup more
#
rm wrap.grd corr_patch.grd phase_patch.grd mask_patch.grd mask3.grd mask3.out phase_patch_masked.grd
#

