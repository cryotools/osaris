# Extract from Ziyadins script
# make_dem_gmtsar.csh

if ($PS == "SM" ) then
  # koordinates of subswath
  set lo = `grep longitude $workdir/SLC/$master/*00[$swath].xml | awk -F'[<|>]' '{print $3}' | gmtinfo -C | awk '{printf "%2.3f %2.3f\n", $1-0.1,$2+0.1}'`
  set la = `grep latitude $workdir/SLC/$master/*00[$swath].xml |  awk -F'[<|>]' '{print $3}' | gmtinfo -C | awk '{printf "%2.3f %2.3f\n", $1-0.1,$2+0.1}'`
  set r = $lo[1]/$lo[2]/$la[1]/$la[2]
  # coordinates of all images
 else     
  set lo = `grep longitude $workdir/SLC/*/*00[$swath].xml | awk -F'[<|>]' '{print $3}' | gmtinfo -C | awk '{printf "%2.3f %2.3f\n", $1-0.1,$2+0.1}'`
  set la = `grep latitude $workdir/SLC/*/*00[$swath].xml |  awk -F'[<|>]' '{print $3}' | gmtinfo -C | awk '{printf "%2.3f %2.3f\n", $1-0.1,$2+0.1}'`
  set r = $lo[1]/$lo[2]/$la[1]/$la[2]
 endif
else if ($sensor == "TSX") then
 set lo = `grep lon $workdir/SLC/$workdir/SLC/$master/*.xml | awk -F'[<|>]' '{print $3}' | gmtinfo -C | awk '{printf "%2.2f %2.2f\n", $1-0.2,$2+0.2}'`
 set la = `grep lat $workdir/SLC/$workdir/SLC/$master/*.xml |  awk -F'[<|>]' '{print $3}' | gmtinfo -C | awk '{printf "%2.2f %2.2f\n", $1-0.2,$2+0.2}'`
 set r = $lo[1]/$lo[2]/$la[1]/$la[2]
else 
 echo "No dem file can be made for other sensors"
 set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
 kill $PPID
 exit 1
endif

echo ""
echo " region covering the frames = -R$r"
echo ""

cd $workdir/topo
#
# check if it is already done!
#
if (! -e dem.grd) then
   echo "cropping dem for swath $swath"
   echo ""
   grdcut $dem_file -R$r -G${workdir}/topo/cut.grd
   grdclip -Sb-1000/NaN ${workdir}/topo/cut.grd -G${workdir}/topo/dem.grd
  if ($sim == 1) then 
   goto makesim
   endif 
endif

# check if the DEM is ok. if yes, skip cropping a new dem 
if ( `grdinfo dem.grd -C |awk '{printf "%2.3f  %2.3f %2.3f  %2.3f\n", $2,$3,$4,$5}'  | awk '{if  ($1 > '$lo[1]'  ||  $2 < '$lo[2]'||  $3 > '$la[1]'|| $4 < '$la[1]' ) print 1;else print 0 }'` == 1 ) then
   echo "cropping dem for  swath $swath"
   echo ""
   grdcut $dem_file -R$r -G${workdir}/topo/cut.grd
   grdclip -Sb-1000/NaN ${workdir}/topo/cut.grd -G${workdir}/topo/dem.grd
     # it is a new swath. so previous simulation files should be removed
     if (-e topo_ra.grd ) then
        rm -f   topo_ra.grd trans.dat
     endif
     if ($sim == 1) then 
       goto makesim
     endif 
else
    # dem file is correct
    echo " dem file is already made"
    echo ""
    # do dem simulation if requested
    if ($sim == 1) then 
      if (! -e topo_ra.grd) then
        if (-e trans.dat ) then
         rm -f   trans.*
        endif
       goto makesim
      else
        echo " topo_ra is already made"
      endif 
    endif  
endif
