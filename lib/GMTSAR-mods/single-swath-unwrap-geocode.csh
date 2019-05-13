
################################
# 5 - start from unwrap phase  #
################################

  if ($stage <= 5 ) then
    if ($threshold_snaphu != 0 ) then
      cd intf
      set ref_id  = `grep SC_clock_start ../SLC/$master.PRM | awk '{printf("%d",int($3))}' `
      set rep_id  = `grep SC_clock_start ../SLC/$slave.PRM | awk '{printf("%d",int($3))}' `
      cd $ref_id"_"$rep_id
      if ((! $?region_cut) || ($region_cut == "")) then
        set region_cut = `grdinfo phase.grd -I- | cut -c3-20`
      endif

#
# landmask
#
      if ($switch_land == 1) then
        cd ../../topo
        if (! -f landmask_ra.grd) then
          landmask.csh $region_cut
        endif
        cd ../intf
        cd $ref_id"_"$rep_id
        ln -s ../../topo/landmask_ra.grd .
      endif

      echo " "
      echo "SNAPHU.CSH - START"
      echo "threshold_snaphu: $threshold_snaphu"
      
      $OSARIS_PATH/lib/GMTSAR-mods/snaphu_OSARIS.csh $threshold_snaphu $defomax $region_cut

      echo "SNAPHU.CSH - END"
      cd ../..
    else 
      echo ""
      echo "SKIP UNWRAP PHASE"
    endif
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
      $OSARIS_PATH/lib/GMTSAR-mods/geocode_OSARIS.csh $threshold_geocode
    else 
      echo "topo_ra is needed to geocode"
      exit 1
    endif
    echo "GEOCODE.CSH - END"
    cd ../..
  endif

# end

