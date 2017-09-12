#!/bin/csh -f
#       $Id$
#
#  Xiaopeng Tong, Jan 14, 2014
#
# process generic L1.1 data
# Automatically process a single frame of interferogram.
# see instruction.txt for details.
#


alias rm 'rm -f'
unset noclobber
#
  if ($#argv != 3) then
    echo ""
    echo "Usage: p2p_SAT_SLC.csh master_image slave_image configuration_file "
    echo ""
    echo "Example: p2p_SAT_SLC.csh TSX_20110608 TSX_20110619 config.tsx.slc.txt"
    echo ""
    echo "         Place the L1.1 data in a directory called raw and a dem.grd file in "
    echo "         a parallel directory called topo.  Execute this command at the directory"
    echo "         location above raw and topo.  The file dem.grd"
    echo "         is a dem that completely covers the SAR frame - larger is OK."
    echo "         If the dem is omitted then an interferogram will still be created"
    echo "         but there will not be geocoded output."
    echo "         A custom dem.grd can be made at the web site http://topex.ucsd.edu/gmtsar"
    echo ""
    echo ""
    exit 1
  endif

# start 

#
#   make sure the files exist
#
# SLCs might be deleted to create space. So if proc_stage > 4 then 
# do not check SLC or PRM files- Ziyadin 
# 
  
set config_file = $3
set stage = `grep proc_stage $config_file      | awk '$1 !~ /#/{if ($2 = "=" && $1 == "proc_stage" ) print $3}'| awk 'END {print $0}'`
 if ($stage > 4) then
 goto skip
 endif
 if((! -f raw/$1.PRM) || (! -f raw/$1.LED) || (! -f raw/$1.SLC)) then
   echo " missing input files  raw/"$1
   exit
 endif
 if((! -f raw/$2.PRM) || (! -f raw/$2.LED) || (! -f raw/$2.SLC)) then
   echo " missing input files  raw/"$2
   exit
 endif
  if(! -f $3 ) then
    echo " no configure file: "$3
    exit
  endif

skip:
# 
# read parameters from configuration file
#
  
    set earth_radius = `grep earth_radius $config_file | awk '{print $3}'`
  if ((! $?earth_radius) || ($earth_radius == "")) then
    set earth_radius = 0
  endif
#
# if filter wavelength is not set then use a default of 100m
#
  set filter = `grep filter_wavelength $config_file      | awk '$1 !~ /#/ {if ($2 = "=" && $1 == "filter_wavelength") print $3 }'| awk 'END {print $0}'`
  if ( "x$filter" == "x" ) then
  set filter = 100
  echo " "
  echo "WARNING filter wavelength was not set in config.txt file"
  echo "        please specify wavelength (e.g., filter_wavelength = 200)"
  echo "        remove filter1 = gauss_alos_200m"
  endif
  #echo $filter

  set stage = `grep proc_stage $config_file      | awk '$1 !~ /#/{if ($2 = "=" && $1 == "proc_stage" ) print $3}'| awk 'END {print $0}'`
  set stop_stage = `grep stop_stage $config_file | awk '$1 !~ /#/{if ($2 = "=" && $1 == "stop_stage") print $3 }'| awk 'END {print $0}'`
  echo ""
  echo "ifg start stage: $stage"
  echo "ifg stop  stage: $stop_stage"
  echo ""
  sleep 5s
 # 
  set filter = `grep filter_wavelength $config_file      | awk '$1 !~ /#/ {if ($2 = "=" && $1 == "filter_wavelength") print $3 }'| awk 'END {print $0}'`
  set earth_radius = `grep earth_radius $config_file     | awk '$1 !~ /#/ {if ($2 = "=" && $1 == "earth_radius") print $3 }'| awk 'END {print $0}'`
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
  set slave = $2 

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
# preprocess the raw data
#
    echo " "
    echo "PREPROCESS - START"
    cd raw
#
# preprocess the raw data make the raw data and copy the PRM to PRM00
# in case the script is run a second time
#
#   make_raw.com
#
    if(-e $master.PRM00) then
       cp $master.PRM00 $master.PRM
       cp $slave.PRM00 $slave.PRM
    else
       cp $master.PRM $master.PRM00
       cp $slave.PRM $slave.PRM00
    endif
#
# set the num_lines to be the min of the master and slave
#
    @ m_lines  = `grep num_lines ../raw/$master.PRM | awk '{printf("%d",int($3))}' `
    @ s_lines  = `grep num_lines ../raw/$slave.PRM | awk '{printf("%d",int($3))}' `
    if($s_lines <  $m_lines) then
      update_PRM.csh $master.PRM num_lines $s_lines
      update_PRM.csh $master.PRM num_valid_az $s_lines
      update_PRM.csh $master.PRM nrows $s_lines
    else
      update_PRM.csh $slave.PRM num_lines $m_lines
      update_PRM.csh $slave.PRM num_valid_az $m_lines
      update_PRM.csh $slave.PRM nrows $m_lines
    endif
#
#   calculate SC_vel and SC_height
#   set the Doppler to be zero
#
    cp $master.PRM $master.PRM0
    calc_dop_orb $master.PRM0 $master.log $earth_radius 0
    cat $master.PRM0 $master.log > $master.PRM
    echo "fdd1                    = 0" >> $master.PRM
    echo "fddd1                   = 0" >> $master.PRM
#
    cp $slave.PRM $slave.PRM0
    calc_dop_orb $slave.PRM0 $slave.log $earth_radius 0
    cat $slave.PRM0 $slave.log > $slave.PRM
    echo "fdd1                    = 0" >> $slave.PRM
    echo "fddd1                   = 0" >> $slave.PRM
    rm *.log
    rm *.PRM0

    cd ..
    echo "PREPROCESS.CSH - END"
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
# align SLC images 
# 
    echo " "
    echo "ALIGN - START"
    cd SLC
    cp ../raw/*.PRM .
    ln -s ../raw/$master.SLC . 
    ln -s ../raw/$slave.SLC . 
    ln -s ../raw/$master.LED . 
    ln -s ../raw/$slave.LED .
    
    cp $slave.PRM $slave.PRM0
    SAT_baseline $master.PRM $slave.PRM0 >> $slave.PRM
    xcorr $master.PRM $slave.PRM -xsearch 128 -ysearch 128
    fitoffset.csh 2 2 freq_xcorr.dat >> $slave.PRM
    resamp $master.PRM $slave.PRM $slave.PRMresamp $slave.SLCresamp 4
    rm $slave.SLC
    mv $slave.SLCresamp $slave.SLC
    cp $slave.PRMresamp $slave.PRM
        
    cd ..
    echo "ALIGN - END"
  endif
 if ($stop_stage == 2) then
 exit 1
 endif 
##################################
# 3 - start from make topo_ra    #
##################################

  if ($stage <= 3) then
#
# clean up
#
    cleanup.csh topo
#
# make topo_ra if there is dem.grd
#
    if ($topo_phase == 1) then 
      echo " "
      echo "DEM2TOPO_RA.CSH - START"
      echo "USER SHOULD PROVIDE DEM FILE"
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
#
#  make sure the range increment of the amplitude image matches the topo_ra.grd
#
        set rng = `gmt grdinfo topo/topo_ra.grd | grep x_inc | awk '{print $7}'`
        cd SLC 
        echo " range decimation is:  " $rng
        slc2amp.csh $master.PRM $rng amp-$master.grd
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
# make and filter interferograms
# 
   echo " "
   if ($skip_filter == 1) then
     echo "INTF.CSH (no filtering) - START"
   else
      echo "INTF.CSH, FILTER.CSH - START"
   endif
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
# make ifg and filter
#
    if($topo_phase == 1) then
      if ($shift_topo == 1) then
        ln -s ../../topo/topo_shift.grd .
        intf.csh $ref.PRM $rep.PRM -topo topo_shift.grd  
       else 
        ln -s ../../topo/topo_ra.grd . 
        intf.csh $ref.PRM $rep.PRM -topo topo_ra.grd 
       endif
    else
        intf.csh $ref.PRM $rep.PRM
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
#
# filter and plot amlitude and interforo
#
   if ($skip_filter == 1) then
    echo ""
    echo " skipping Golstein filtering ..."
     echo ""
  else 
    echo " landmask (if set to yes) and filter real an imaginary files with  Golstein filtering"
    echo ""
    sleep 5s
   endif 
   filter_multi.csh $ref.PRM $rep.PRM $filter $dec $skip_filter $region_cut
   
    cd ../..
    echo "INTF.CSH, FILTER.CSH - END"
endif

  endif
  if ($stop_stage == 4) then
  exit 1
  endif 
################################
# 5 - start from unwrap phase  #
################################
 if ($stage <= 5 ) then
    if ($threshold_snaphu != 0 ) then
      set ref_id  = `grep SC_clock_start SLC/$master.PRM | awk '{printf("%d",int($3))}' `
      set rep_id  = `grep SC_clock_start SLC/$slave.PRM | awk '{printf("%d",int($3))}' `
      cd intf/$ref_id"_"$rep_id
      if ((! $?region_cut) || ($region_cut == "" ) && ($region_cut_geo == "" )) then
        set region_cut = `grdinfo phase.grd -I- | cut -c3-20`
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
      echo "$threshold_snaphu $defomax $region_cut $interpolate"   
      
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
    rm -f raln.grd ralt.grd
    if ($topo_phase == 1) then
      rm -rf trans.dat 
      ln -s  ../../topo/trans.dat . 
      echo "threshold_geocode: $threshold_geocode"
      geocode_multi.csh $threshold_geocode $config_file
    else 
      echo "topo_ra is needed to geocode"
      exit 1
    endif
    echo "GEOCODE.CSH - END"
     # clean to get space - Ziyadin Cakir
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

