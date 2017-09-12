#!/bin/csh -f
#       $Id$
#
#  Matt Wei, May 2010
#   based on Xiaopeng Tong, Feb 10, 2010
#
# Automatically process a single frame of interferogram.
# see instruction.txt for details.
#
alias rm 'rm -f'
unset noclobber
#
if ($#argv < 3) then
    echo ""
    echo "Usage: p2p_ENVI.csh master_stem slave_stem configuration_file"
    echo ""
    echo "Example: p2p_ENVI.csh ENV1_2_077_0639_0657_41714 ENV1_2_077_0639_0657_42716 config.envi.txt"
    echo ""
    echo "         Place the raw data in a directory called raw and a dem.grd file in "
    echo "         a parallel directory called topo.  The two files of raw data must have a suffix .baq"
    echo "         Execute this command at the directory location above raw and topo.  The file dem.grd"
    echo "         is a dem that completely covers the SAR frame - larger is OK."
    echo "         If the dem is omitted then an interferogram will still be created"
    echo "         but there will not be geocoded output."
    echo "         A custom dem.grd can be made at the web site http://topex.ucsd.edu/gmtsar"
    echo ""
    exit 1
  endif

# start

#
#   make sure the files exist
#
 if(! -f $3 ) then
   echo " no configure file: "$3
   exit
 endif
# 
# read parameters from configuration file
  set config_file = $3
  set near_range = `grep near_range $config_file | awk '$1 !~ /#/ {if ($2 = "=" && $1 == "near_range") print $3 }'| awk 'END {print $0}'`
  if ((! $?near_range) || ($near_range == "")) then 
    set near_range = 0 
  endif
  set earth_radius = `grep earth_radius $config_file | awk '$1 !~ /#/ {if ($2 = "=" && $1 == "earth_radius") print $3 }'| awk 'END {print $0}'`
  if ((! $?earth_radius) || ($earth_radius == "")) then 
    set earth_radius = 0
  endif
  set npatch = `grep num_patches $config_file | awk '$1 !~ /#/{if ($2 = "=" && $1 == "num_patches" ) print $3}'| awk 'END {print $0}'`
  if ((! $?npatch) || ($npatch == "")) then
    set npatch = 0
  endif
 
  
  set stage = `grep proc_stage $config_file      | awk '$1 !~ /#/{if ($2 = "=" && $1 == "proc_stage" ) print $3}'| awk 'END {print $0}'`
  set stop_stage = `grep stop_stage $config_file | awk '$1 !~ /#/{if ($2 = "=" && $1 == "stop_stage") print $3 }'| awk 'END {print $0}'`
  echo ""
  echo "ifg start stage: $stage"
  echo "ifg stop  stage: $stop_stage"
  echo ""
  sleep 5s
 # 
  set fd = `grep fd1 $config_file                        | awk '$1 !~ /#/{if ($2 = "=" && $1 == "fd1" ) print $3}'| awk 'END {print $0}'`
  set filter = `grep filter_wavelength $config_file      | awk '$1 !~ /#/ {if ($2 = "=" && $1 == "filter_wavelength") print $3 }'| awk 'END {print $0}'`
  set clean = `grep clean $config_file                   | awk '$1 !~ /#/ {if ($2 = "=" && $1 == "clean") print $3}'| awk 'END {print $0}'`
  set topo_phase = `grep topo_phase $config_file         | awk '$1 !~ /#/ {if ($2 = "=" && $1 == "topo_phase") print $3}' | awk 'END {print $0}'` 
  set shift_topo = `grep shift_topo $config_file         | awk '$1 !~ /#/ {if ($2 = "=" && $1 == "shift_topo") print $3}' | awk 'END {print $0}'` 
  set switch_master = `grep switch_master $config_file   | awk '$1 !~ /#/ {if ($2 = "=" && $1 == "switch_master") print $3}' | awk 'END {print $0}'` 
  set dec = `grep dec_factor $config_file                      | awk '$1 !~ /#/ {if ($2 = "=" && $1 == "dec_factor") print $3}' | awk 'END {print $0}'` 
  set threshold_snaphu = `grep threshold_snaphu $config_file   | awk '$1 !~ /#/ {if ($2 = "=" && $1 == "threshold_snaphu") print $3}' | awk 'END {print $0}'` 
  set threshold_geocode = `grep threshold_geocode $config_file | awk '$1 !~ /#/ {if ($2 = "=" && $1 == "threshold_geocode") print $3}' | awk 'END {print $0}'`
  set region_cut = `grep region_cut $config_file         | awk '$1 !~ /#/ {if ($2 = "=" && $1 == "region_cut") print $3}' | awk 'END {print $0}'`
  set region_cut_geo = `grep region_cut_geo $config_file | awk '$1 !~ /#/ {if ($2 = "=" && $1 == "region_cut_geo") print $3}' | awk 'END {print $0}'`
  set switch_land = `grep switch_land $config_file       | awk '$1 !~ /#/ {if ($2 = "=" && $1 == "switch_land") print $3}'| awk 'END {print $0}'`
  set skip_filter = `grep skip_filter $config_file       | awk '$1 !~ /#/ {if ($2 = "=" && $1 == "skip_filter") print $3}'| awk 'END {print $0}'`
  set defomax = `grep defomax $config_file               | awk '$1 !~ /#/ {if ($2 = "=" && $1 == "defomax") print $3}'| awk 'END {print $0}'`
  set interpolate = `grep interpolate $config_file       | awk '$1 !~ /#/ {if ($2 = "=" && $1 == "interpolate") print $3}'| awk 'END {print $0}'`
 # 
#
# if filter wavelength is not set then use a default of 200m
#

 if ( "x$filter" == "x" ) then
  set filter = 200
  echo " "
  echo "WARNING filter wavelength was not set in config.txt file"
  echo "        please specify wavelength (e.g., filter_wavelength = 200)"
  echo "        remove filter1 = gauss_alos_200m"
  endif
 # echo $filter
  
 if ($interpolate == "") then
   set interpolate = 0
  endif
  if ($skip_filter == "") then
   set skip_filter = 0
  endif
  if ($switch_land == "") then
   set switch_land = 0
  endif
   if ($dec == "") then
   set dec = 2
  endif
   if ($clean == "") then
   set clean = 0
  endif
 
#
# read file names of raw data
#
  set master = $1
  set slave =  $2 

  if ($switch_master == 0) then
    set ref = $master
    set rep = $slave
  else if ($switch_master == 1) then
    set ref = $slave
    set rep = $master
  else
    echo "Wrong paramter: switch_master "$switch_master
  endif
#
# make working directories
#  
  mkdir -p intf/ SLC/

#############################
# 1 - start from preprocess #
#############################

  if ($stage == 1) then
#
# first clean up 
# 
    cleanup.csh raw
# 
# preprocess the raw data 
#
    echo ""
    echo " PREPROCESS Envisat DATA  -- START"
    cd raw
    ENVI_pre_process $master $near_range $earth_radius $npatch $fd
    set NEAR = `grep near_range $master.PRM | awk '{print $3}'`
    set RAD = `grep earth_radius $master.PRM | awk '{print $3}'`
    ENVI_pre_process $slave $NEAR $RAD $npatch $fd
#   
#   check patch number, if different, use the smaller one
# 
    set pch1 = `grep patch $master.PRM | awk '{printf("%d ",$3)}'`
    set pch2 = `grep patch $slave.PRM | awk '{printf("%d ",$3)}'`
    echo "Different number of patches: $pch1 $pch2"
    if ($pch1 != $pch2) then
      if ($pch1 < $pch2) then
        update_PRM.csh $slave.PRM num_patches $pch1
        echo "Number of patches is set to $pch1"
      else
        update_PRM.csh $master.PRM num_patches $pch2
        echo "Number of patches is set to $pch2"
      endif
    endif
#
#   set the Doppler to be the average of the two
#
    grep fd1 $master.PRM | awk '{printf("%f ",$3)}' > temp
    grep fd1 $slave.PRM | awk '{printf("%f",$3)}' >> temp
    set fda = `cat temp | awk '{print( ($1 + $2)/2.)}'`
    echo " use average Doppler $fda "
    update_PRM.csh $master.PRM fd1 $fda
    update_PRM.csh $slave.PRM fd1 $fda
    rm -r temp
    cd ..
    echo " PREPROCESS Envisat DATA  -- END"
  endif
  if ($stop_stage == 1) then
  exit 1
  endif 
#############################################
# 2 - start from focus and align SLC images #
#############################################
  
  if ($stage <= 2) then
# 
# clean up 
#
    cleanup.csh SLC
#
# focus and align SLC files
# 
    echo " "
    echo "ALIGN.CSH - START"
    cd SLC
    cp ../raw/*.PRM .
    ln -s ../raw/$master.raw . 
    ln -s ../raw/$slave.raw . 
    ln -s ../raw/$master.LED . 
    ln -s ../raw/$slave.LED .
    align.csh ENVI $master $slave 
    cd ..
    echo "ALIGN.CSH - END"
  endif
  if ($stop_stage == 2) then
  exit 1
  endif 
##################################
# 3 - start from make topo_ra  #
##################################

  if ($stage <= 3) then
#
# clean up
#
    cleanup.csh topo
#
# make topo_ra if there is a dem.grd
#
    if ($topo_phase == 1) then
      echo " "
      echo " DEM2TOPOP_RA.CSH - START "
      echo " USER SHOULD PROVIDE DEM FILE"
      cd topo
      cp ../SLC/$master.PRM master.PRM 
      ln -s ../raw/$master.LED . 
      if (-f dem.grd) then 
        dem2topo_ra.csh master.PRM dem.grd 
      else 
        echo "no DEM file found: " dem.grd 
        exit 1
      endif
      cd .. 
      echo "DEM2TOPO_RA.CSH - END"
# 
# shift topo_ra
# 
      if ($shift_topo == 1) then 
        echo " "
        echo "OFFSET_TOPO - START"
        cd SLC 
        slc2amp.csh $master.PRM 1 amp-$master.grd 
        cd ..
        cd topo
        ln -s ../SLC/amp-$master.grd . 
        offset_topo amp-$master.grd topo_ra.grd 0 0 7 topo_shift.grd 
        cd ..
        echo "OFFSET_TOPO - END"
      else if ($shift_topo == 0) then 
          echo "NO TOPO_RA SHIFT "
      else 
          echo "Wrong paramter: shift_topo "$shift_topo
          exit 1
      endif

    else if ($topo_phase == 0) then 
      echo "NO TOPO_RA IS SUBSTRACTED"
    else 
      echo "Wrong paramter: topo_phase "$topo_phase
      exit 1
    endif
  endif
  if ($stop_stage == 3) then
  exit 1
  endif 
##################################################
# 4 - start from make and filter interferograms  #
##################################################

  if ($stage <= 4) then
#
# clean up
#
    cleanup.csh intf
# 
# make interferogram
# 
    echo " "
    echo "INTF.CSH, FILTER.CSH - START"
    cd intf/
    set ref_id  = `grep SC_clock_start ../raw/$master.PRM | awk '{printf("%d",int($3))}' `
    set rep_id  = `grep SC_clock_start ../raw/$slave.PRM | awk '{printf("%d",int($3))}' `
    mkdir $ref_id"_"$rep_id
    cd $ref_id"_"$rep_id
    ln -s ../../raw/$ref.LED . 
    ln -s ../../raw/$rep.LED .
    ln -s ../../SLC/$ref.SLC . 
    ln -s ../../SLC/$rep.SLC .
    cp ../../SLC/$ref.PRM . 
    cp ../../SLC/$rep.PRM .
#
# landmask
#
      if ($switch_land == 1) then
        cd ../../topo
       # in case reruning with a different region_cut
        if (-e landmask_ra.grd) then
          rm -f landmask_ra.grd
        endif
       echo ""
       echo "MAKE LANDMASK -- START"
       echo "REQUIRE FULL RESOLUTION COASTLINE FROM GMT"
       echo ""
       gmt grdlandmask -Glandmask.grd `gmt grdinfo -I- dem.grd` `gmt grdinfo -I dem.grd`  -V -NNaN/1 -Df
       proj_ll2ra.csh trans.dat landmask.grd landmask_ra.grd
       echo "MAKE LANDMASK -- END"
        cd ../intf/$ref_id"_"$rep_id
        ln -sf ../../topo/landmask_ra.grd .
      endif
#
    if($topo_phase == 1) then
      if ($shift_topo == 1) then
        ln -s ../../topo/topo_shift.grd .
        intf.csh $ref.PRM $rep.PRM -topo topo_shift.grd
       # filter.csh $ref.PRM $rep.PRM $filter $dec
      else 
        ln -s ../../topo/topo_ra.grd . 
        intf.csh $ref.PRM $rep.PRM -topo topo_ra.grd
       # filter.csh $ref.PRM $rep.PRM $filter $dec
      endif
    else
      intf.csh $ref.PRM $rep.PRM
      #filter.csh $ref.PRM $rep.PRM $filter $dec
    endif
   #     
 # geo2radar of region_cut_geo
 # 
    if ( $#region_cut_geo == 1 )  then
     echo "converting region_cut_geo to region_cut "
     geo2radar.csh $region_cut_geo
        if  (`cat region_cut | wc -l` != 0) then
            set region_cut = `cat region_cut`
            #echo "region_cut = $region_cut"
        else
            echo "dem does not cover the entire region selected. Check the region_cut_geo "
            exit 1
        endif 
    endif
    
   if ($skip_filter == 1) then
    echo ""
    echo " skipping Golstein filtering ..."
   else 
    echo " landmask (if set to yes) and filter real an imaginary files with  Golstein filtering"
    echo ""
    sleep 5s
   endif 
  
      # filter.csh $ref.PRM $rep.PRM $filter $dec
  filter_multi.csh $ref.PRM $rep.PRM $filter $dec $skip_filter $region_cut
  cd ../..
   
    echo "INTF.CSH, FILTER.CSH - END"
  endif
  
  if ($stop_stage == 4) then
   exit 1
  endif 
################################
# 5 - start from unwrap phase  #
################################

  if ($stage <= 5 ) then
    if ($threshold_snaphu != 0 ) then
      cd intf
      set ref_id  = `grep SC_clock_start ../SLC/$master.PRM | awk '{printf("%d",int($3))}' `
      set rep_id  = `grep SC_clock_start ../SLC/$slave.PRM | awk '{printf("%d",int($3))}' `
      cd $ref_id"_"$rep_id
       if ((! $?region_cut) || ($region_cut == "" ) & ($region_cut_geo == "" )) then
       set region_cut = `gmt grdinfo phase.grd -I- | cut -c3-20`
      endif
  
  if ( $#region_cut_geo == 1 )  then
      # geo2radar.csh $region_cut_geo
       set region_cut = `cat region_cut`
       # make sure the region is not entirely outside the frame
       set width = `echo $region_cut | awk -F"/" '{if ($3 == $4 || $1 == $2) print 1}'`
        if ($width == 1) then
         echo ""
         echo 'REGION_CUT_GEO OUTSIDE THE FRAME: skipping unwrapping'
         echo ""
         goto skipunw
        endif
      endif
#
      echo " "
      echo "SNAPHU.CSH - START"
      echo "threshold_snaphu: $threshold_snaphu"

      #snaphu.csh $threshold_snaphu $defomax $region_cut
      snaphu_multi.csh $threshold_snaphu $defomax $region_cut $interpolate
 
      echo "SNAPHU.CSH - END"
      cd ../..
    else 
      echo ""
      skipunw:
      echo "SKIP UNWRAP PHASE"
    endif
  endif
  if ($stop_stage == 5) then
   exit 1
  endif 
###########################
# 6 - start from geocode  #
###########################

  if ($stage <= 6) then
    cd intf
    set ref_id  = `grep SC_clock_start ../SLC/$master.PRM | awk '{printf("%d",int($3))}' `
    set rep_id  = `grep SC_clock_start ../SLC/$slave.PRM | awk '{printf("%d",int($3))}' `
    cd $ref_id"_"$rep_id
    echo " "
    echo "GEOCODE.CSH - START"
    rm raln.grd ralt.grd
    if ($topo_phase == 1) then
      rm trans.dat
      ln -s  ../../topo/trans.dat . 
      echo "threshold_geocode: $threshold_geocode"
      #geocode.csh $threshold_geocode
      geocode_multi.csh $threshold_geocode $config_file
    else 
      echo "topo_ra is needed to geocode"
      exit 1
    endif
    echo "GEOCODE.CSH - END"
    cd ../..
    
      if ($clean == 2) then   
      if (-e  unwrap_mask_ll.grd & -e corr_ll.grd) then 
       rm -f filtcorr.grd ralt.grd raln.grd  landmask_ra.grd corr.ps landmask_ra_patch.grd los_grad.grd los.grd mask2_patch.grd mask3.grd mask2.grd  phasefilt_mask.grd  phase_mask.grd topo_ra.grd unwrap.grd unwrap_mask.grd 
       rm -f phase.ps phase_mask.ps phasefilt.ps disp*ps
       # these are needed to re unwrap 
       #rm corr.grd display_amp.grd mask.grd phase.grd    
      endif  
     endif
     # deleting all grids except corr_ll.grd and unwrap_mask_ll.grd
     # all steps have to be rerun for re unwrapping 
     if ($clean == 3) then   
      if (-e  unwrap_mask_ll.grd & -e corr_ll.grd) then 
       rm -f filtcorr.grd ralt.grd raln.grd  landmask_ra.grd corr.ps landmask_ra_patch.grd los_grad.grd los.grd mask2_patch.grd mask3.grd mask2.grd  phasefilt_mask.grd  phase_mask.grd topo_ra.grd unwrap.grd unwrap_mask.grd imagfilt.grd amp.grd amp2.grd amp1.grd realfilt.grd corr.grd display_amp.grd mask.grd phase.grd  
       rm -f phase.ps phase_mask.ps phasefilt.ps disp*ps phasefilt_mask.ps *.eps      
       endif   
     endif
  endif

# end

