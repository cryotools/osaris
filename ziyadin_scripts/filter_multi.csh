#!/bin/csh -f
#       $Id$
#
#  Xiaopeng Tong and David Sandwell 
#  FEB 4 2010
#  Matt Wei May 4 2010, ENVISAT
#  DTS - May 26, 2010, added phase gadient
#  EF, DTS, XT - Jan 10 2014, TSX
#
# Convolve the real.grd and imag.grd with gaussian filters. 
# Form amplitude, phase, phase gradient, and correlation images. 
#
#
  alias rm 'rm -f'
  gmt set IO_NC4_CHUNK_SIZE classic
#
#
  if ($#argv < 5) then
errormessage:
    echo ""
    echo "Usage: filter.csh master.PRM slave.PRM filter decimation skip_filter_phase (1=yes; else=no) [region_cut]"
    echo ""
    echo " Apply gaussian filter to amplitude and phase images."
    echo " "
    echo " filter -  wavelength of the filter in meters (0.5 gain)"
    echo " decimation - (1) better resolution, (2) smaller files"
    echo " "
    echo "Example: filter.csh IMG-HH-ALPSRP055750660-H1.0__A.PRM IMG-HH-ALPSRP049040660-H1.0__A.PRM 300  2 1 200/1500/500/3500"
    echo ""
    exit 1
  endif
  echo "filter.csh"
#
# define filter and decimation variables
#
echo $0 $1 $2 $3 $4 $5 $6
  set sharedir = `gmtsar_sharedir.csh`
  set filter3 = $sharedir/filters/fill.3x3
  set filter4 = $sharedir/filters/xdir
  set filter5 = $sharedir/filters/ydir
  set mast = $1
  set slav = $2
  set filt = $3
  set dec  = $4
  set az_lks = 4 
  set skip_filter_goldstein = $5
  set skip_filter_conv = $6
  set region_cut = $7
  set PRF = `grep PRF *.PRM | awk 'NR == 1 {printf("%d", $3)}'`
  if( $PRF < 1000 ) then
     set az_lks = 1
  endif
#
# look for range sampling rate
#
  set rng_samp_rate = `grep rng_samp_rate $mast | awk 'NR == 1 {printf("%d", $3)}'`
#
# set the range spacing in units of image range pixel size
#
  if ($?rng_samp_rate) then
    if ($rng_samp_rate > 110000000) then 
      set dec_rng = 4
      set filter1 = $sharedir/filters/gauss15x5
    else if ($rng_samp_rate < 110000000 && $rng_samp_rate > 20000000) then
      set dec_rng = 2
      set filter1 = $sharedir/filters/gauss15x5
#
# special for TOPS mode
#
      if($az_lks == 1) then
        set filter1 = $sharedir/filters/gauss5x5
      endif
    else  
      set dec_rng = 1
      set filter1 = $sharedir/filters/gauss15x3
    endif
  else
    echo "Undefined rng_samp_rate in the master PRM file"
    exit 1
  endif
#/opt/GMT5SAR_new/bin/filter.csh S1A20161103_ALL_F2.PRM S1A20160823_ALL_F2.PRM 200 2 1 5000/20000/1/6000

#  make the custom filter2 and set the decimation
#
  make_gaussian_filter $mast $dec_rng $az_lks $filt > ijdec
  set filter2 = gauss_$filt
  set idec = `cat ijdec | awk -v dc="$dec" '{ print dc*$1 }'`
  set jdec = `cat ijdec | awk -v dc="$dec" '{ print dc*$2 }'`
  echo $filter2 $idec $jdec
#
# filter the two amplitude images
#
  echo "making amplitudes..."
  conv $az_lks $dec_rng $filter1 $mast amp1_tmp.grd=bf
  conv $idec $jdec $filter2 amp1_tmp.grd=bf amp1.grd 
  gmt grdmath amp1.grd 0.5 POW = display_amp1.grd -Vq 
  rm amp1_tmp.grd
  conv $az_lks $dec_rng $filter1 $slav amp2_tmp.grd=bf
  conv $idec $jdec $filter2 amp2_tmp.grd=bf amp2.grd
  gmt grdmath amp2.grd 0.5 POW = display_amp2.grd -Vq 
  rm amp2_tmp.grd
#
# filter the real and imaginary parts of the interferogram
# also compute gradients
#
  echo "filtering interferogram..."
  conv $az_lks $dec_rng $filter1 real.grd=bf real_tmp.grd=bf
  conv $idec $jdec $filter2 real_tmp.grd=bf realfilt.grd
#  conv $dec $dec $filter4 real_tmp.grd xreal.grd
#  conv $dec $dec $filter5 real_tmp.grd yreal.grd
  rm real_tmp.grd 
##  rm real.grd
  conv $az_lks $dec_rng $filter1 imag.grd=bf imag_tmp.grd=bf
  conv $idec $jdec $filter2 imag_tmp.grd=bf imagfilt.grd
#  conv $dec $dec $filter4 imag_tmp.grd ximag.grd
#  conv $dec $dec $filter5 imag_tmp.grd yimag.grd
  rm imag_tmp.grd 
##  rm imag.grd
#
# form amplitude image
#
  echo "making amplitude..."
  gmt grdmath realfilt.grd imagfilt.grd HYPOT  = amp.grd  -Vq 
  gmt grdmath amp.grd 0.5 POW FLIPUD = display_amp.grd  -Vq 
  
#
# form the correlation
#
  echo "making correlation..."
  set thresh = "5.e-21"
  gmt grdmath amp1.grd amp2.grd MUL = tmp.grd -Vq 
  gmt grdmath tmp.grd $thresh GE 0 NAN = mask.grd -Vq 
  gmt grdmath amp.grd tmp.grd SQRT DIV mask.grd MUL FLIPUD = tmp2.grd=bf -Vq 
  conv 1 1 $filter3 tmp2.grd=bf corr.grd
#
# form the phase 
#
  echo "making phase..."
  gmt grdmath imagfilt.grd realfilt.grd ATAN2 mask.grd MUL FLIPUD = phase.grd -Vq 
  gmt makecpt -Crainbow -T-3.15/3.15/0.1 -Z -N -Vq  > ! phase.cpt
# gmt makecpt -Cgray -T-3.14/3.14/0.1 -Z -N > phase_bw.cpt
# echo "N  255   255   254" >> phase_bw.cpt
#
# set grdimage options
#
  gmtset PROJ_LENGTH_UNIT = cm
  gmtset PS_MEDIA = A4
  set r = `grdinfo -C  amp1.grd  | awk '{print $2"/"$3"/"$4"/"$5}' `
  set B = `echo $r | awk -F"/" '{if ((($2-$1)/5) > 1000) x = substr(int(($2-$1)/5),1,1)"000"; else x = substr(int(($2-$1)/5),1,2)"0"; if ((($4 - $3)/5) > 1000) y = substr(int(($4-$3)/5),1,1)"000";else y = substr(int(($4-$3)/5),1,2)"0"; print x,y, x/2, y/2}'`
  set ratio = 4
  set rr = `echo  $r | awk -F"/" '{print (($2-$1)/(($4-$3)*'$ratio'))}'`
  if ( `echo $rr | awk '{ if ($1 > 1 ) print 1 ;else print 0}'` == 1 ) then
   set jx = 10
   set jy = ` awk ' BEGIN {print  '$jx' / '$rr' }'`
  else
   set jy = 18
   set jx = ` awk ' BEGIN {print '$rr' * '$jy' }'`
  endif
  set boundR = $B[1]f$B[3]
  set boundA = $B[2]f$B[4]
  set scale = -JX$jx/$jy 

  #set scale = "-JX6.5i"
  gmt set COLOR_MODEL = hsv
  gmt grdmath amp1.grd 0.5 POW FLIPUD = display_amp1.grd -Vq 
  gmt grdmath amp2.grd 0.5 POW FLIPUD = display_amp2.grd -Vq 
  set AMAX = `gmt grdinfo -L2 display_amp1.grd  -Vq | grep stdev | awk '{ print 3*$5}'`
  gmt grd2cpt display_amp1.grd -Z -D -L0/$AMAX -Cgray -Vq  > ! amp1.cpt
  echo "N  255   255   254" >> amp1.cpt
  set AMAX = `gmt grdinfo -L2 display_amp2.grd  -Vq | grep stdev | awk '{ print 3*$5 }'`
  gmt grd2cpt display_amp2.grd -Z -D -L0/$AMAX -Cgray -Vq  > ! amp2.cpt
  echo "N  255   255   254" >> amp2.cpt
  set AMAX = `gmt grdinfo -L2 display_amp.grd  -Vq | grep stdev | awk '{ print 3*$5 }'`
  gmt grd2cpt display_amp.grd -Z -D -L0/$AMAX -Cgray  -Vq > ! display_amp.cpt
  echo "N  255   255   254" >> display_amp.cpt
  gmt makecpt -T0./.8/0.1 -Cgray -Z -N > ! corr.cpt
  echo "N  255   255   254" >> corr.cpt
  gmt grdimage display_amp1.grd -Camp1.cpt $scale -B"$boundR":Range:/"$boundA":Azimuth:WSen   -Y1 -P  -Vq   > ! amp1.ps
  gmt grdimage display_amp2.grd -Camp2.cpt $scale -B"$boundR":Range:/"$boundA":Azimuth:WSen   -Y1 -P  -Vq   > ! amp2.ps
  gmt grdimage corr.grd $scale -Ccorr.cpt -B"$boundR":Range:/"$boundA":Azimuth:WSen   -Y1 -P -K  -Vq > ! corr.ps
  gmt psscale -D3.3/-1.5/5/0.2h -Ccorr.cpt -B0.2:correlation: -O -E -Vq>> corr.ps
  gmt grdimage display_amp.grd -Cdisplay_amp.cpt $scale -B"$boundR":Range:/"$boundA":Azimuth:WSen   -Y1 -P  -Vq  > ! amp.ps
  gmt grdimage phase.grd $scale -B"$boundR":Range:/"$boundA":Azimuth:WSen -Cphase.cpt   -Y1 -P -K  -Vq > ! phase.ps
  gmt psscale -D3.3/-1.5/5/0.2h -Cphase.cpt -B1.57:"phase, rad": -O -Vq >> phase.ps  
  
if ($region_cut != "") then
  set r = $region_cut 
  set B = `echo $r | awk -F"/" '{if ((($2-$1)/5) > 1000) x = substr(int(($2-$1)/5),1,1)"000"; else x = substr(int(($2-$1)/5),1,2)"0"; if ((($4 - $3)/5) > 1000) y = substr(int(($4-$3)/5),1,1)"000";else y = substr(int(($4-$3)/5),1,2)"0"; print x,y, x/2, y/2}'`
  set ratio = 4
  set rr = `echo  $r | awk -F"/" '{print (($2-$1)/(($4-$3)*'$ratio'))}'`
  if ( `echo $rr | awk '{ if ($1 > 1 ) print 1 ;else print 0}'` == 1 ) then
   set jx = 10
   set jy = ` awk ' BEGIN {print  '$jx' / '$rr' }'`
  else
   set jy = 18
   set jx = ` awk ' BEGIN {print '$rr' * '$jy' }'`
  endif
  set boundR = $B[1]f$B[3]
  set boundA = $B[2]f$B[4]
  set scale = -JX$jx/$jy 
  set AMAX = `gmt grdinfo -L2 display_amp1.grd -Vq -R$region_cut  | grep stdev | awk '{ print 4*$5}'`
  gmt grd2cpt display_amp1.grd -Z -D -L0/$AMAX -Cgray  -Vq -R$region_cut > ! amp1.cpt
  echo "N  255   255   254" >> amp1.cpt
  set AMAX = `gmt grdinfo -L2 display_amp2.grd   -Vq -R$region_cut  | grep stdev | awk '{ print 4*$5}'`
  gmt grd2cpt display_amp2.grd -Z -D -L0/$AMAX -Cgray   -Vq -R$region_cut  > ! amp2.cpt
  echo "N  255   255   254" >> amp2.cpt
  set AMAX = `gmt grdinfo -L2 display_amp.grd -R$region_cut  -Vq | grep stdev | awk '{ print 4*$5 }'`
  gmt grd2cpt display_amp.grd -Z -D -L0/$AMAX -Cgray -R$region_cut  -Vq > ! display_amp.cpt
  echo "N  255   255   254" >> display_amp.cpt
  gmt makecpt -T0./.8/0.1 -Cgray -Z -N > ! corr.cpt
  echo "N  255   255   254" >> corr.cpt
  gmt grdimage display_amp1.grd -Camp1.cpt $scale -B"$boundR":Range:/"$boundA":Azimuth:WSen   -Y1 -P  -Vq -R$region_cut > ! amp1_cut.ps
  gmt grdimage display_amp2.grd -Camp2.cpt $scale -B"$boundR":Range:/"$boundA":Azimuth:WSen   -Y1 -P  -Vq -R$region_cut > ! amp2_cut.ps
  gmt grdimage corr.grd $scale -Ccorr.cpt -B"$boundR":Range:/"$boundA":Azimuth:WSen   -Y1 -P -K -R$region_cut -Vq > ! corr_cut.ps
  gmt psscale -D3.3/-1.5/5/0.2h -Ccorr.cpt -B0.2:correlation: -O -E  -Vq >> corr_cut.ps
  gmt grdimage display_amp.grd -Cdisplay_amp.cpt $scale -B"$boundR":Range:/"$boundA":Azimuth:WSen   -Y1 -P -R$region_cut -Vq  > ! amp_cut.ps
  gmt grdimage phase.grd $scale -B"$boundR":Range:/"$boundA":Azimuth:WSen -Cphase.cpt   -Y1 -P -K -R$region_cut -Vq  > ! phase_cut.ps
  gmt psscale -D3.3/-1.5/5/0.2h -Cphase.cpt -B1.57:"phase, rad": -O >> phase_cut.ps  
endif
#  
# filtered phase with the Werner/Goldstein 
# 

if ($skip_filter_goldstein != 1) then  
 echo "filtering phase..."
 if (-e landmask_ra.grd) then
  echo "landmasking before Werner/Goldstein magick filter..."
  gmt grdsample landmask_ra.grd `grdinfo realfilt.grd -Ir` `grdinfo realfilt.grd -I` -Glandmask_ra_ph.grd
  gmt grdmath landmask_ra_ph.grd   FLIPUD  realfilt.grd MUL = real_masked.grd -Vq
  gmt grdmath landmask_ra_ph.grd   FLIPUD imagfilt.grd  MUL = imag_masked.grd -Vq
  phasefilt -imag imag_masked.grd -real real_masked.grd  -amp1 amp1.grd -amp2 amp2.grd -psize 32
 else
  # phasefilt -imag imagfilt.grd -real realfilt.grd -amp1 amp1.grd -amp2 amp2.grd -psize 16 -complex_out
  phasefilt -imag imagfilt.grd -real realfilt.grd -amp1 amp1.grd -amp2 amp2.grd -psize 32
 endif 
  gmt grdedit filtphase.grd `gmt grdinfo mask.grd -I- --FORMAT_FLOAT_OUT=%.12lg` 
  gmt grdmath filtphase.grd mask.grd MUL FLIPUD = phasefilt.grd
  rm filtphase.grd landmask_ra.grd 
  # if no filtering then make a fake filtered phase required by unrapping etc
else
  if (-e landmask_ra.grd) then
   echo "landmasking   phase"
   gmt grdsample landmask_ra.grd `grdinfo realfilt.grd -Ir` `grdinfo realfilt.grd -I` -Glandmask_ra_ph.grd
   gmt grdmath landmask_ra_ph.grd   FLIPUD  realfilt.grd MUL = real_masked.grd -Vq
   gmt grdmath landmask_ra_ph.grd   FLIPUD imagfilt.grd  MUL = imag_masked.grd -Vq
   gmt grdmath  imag_masked.grd real_masked.grd  ATAN2  FLIPUD = phasefilt.grd -Vq 
  else 
    cp phase.grd phasefilt.grd 
  endif
endif
#
 if ($region_cut != "") then
  gmt grdimage phasefilt.grd $scale -B"$boundR":Range:/"$boundA":Azimuth:WSen -Cphase.cpt  -Y5 -P -K  -R$region_cut> ! phasefilt_cut.ps
  gmt psscale -D3.3/-1.5/5/0.2h -Cphase.cpt -B1.57:"phase, rad": -O >> phasefilt_cut.ps
 else
  gmt grdimage phasefilt.grd $scale -B"$boundR":Range:/"$boundA":Azimuth:WSen -Cphase.cpt  -Y5 -P -K >!  phasefilt.ps
  gmt psscale -D3.3/-1.5/5/0.2h -Cphase.cpt -B1.57:"phase, rad": -O >> phasefilt.ps
 endif
# gmt grdimage phasefilt.grd $scale -B"$boundR":Range:/"$boundA":Azimuth:WSen -Cphase_bw.cpt  -Y5 -P -K > phase_bw.ps
# gmt psscale -D3.3/-1.5/5/0.2h -Cphase_bw.cpt -B1.57:"phase, rad": -O >> phase_bw.ps
# 
#  form the phase gradients
#
#  echo "making phase gradient..."
#  gmt grdmath amp.grd 2. POW = amp_pow.grd
#  gmt grdmath realfilt.grd ximag.grd MUL imagfilt.grd xreal.grd MUL SUB amp_pow.grd DIV mask.grd MUL FLIPUD = xphase.grd
#  gmt grdmath realfilt.grd yimag.grd MUL imagfilt.grd yreal.grd MUL SUB amp_pow.grd DIV mask.grd MUL FLIPUD = yphase.grd 
#  gmt makecpt -Cgray -T-0.7/0.7/0.1 -Z -N > phase_grad.cpt
#  echo "N  255   255   254" >> phase_grad.cpt
#  gmt grdimage xphase.grd $scale -Cphase_grad.cpt -X.2 -Y.5 -P > xphase.ps
#  gmt grdimage yphase.grd $scale -Cphase_grad.cpt -X.2 -Y.5 -P > yphase.ps
#
# flip the mask file for unwrapping   
mv mask.grd tmp.grd 
gmt grdmath tmp.grd FLIPUD = mask.grd
#
# delete files
#
rm -fr tmp.grd tmp2.grd ximag.grd yimag.grd xreal.grd yreal.grd  

