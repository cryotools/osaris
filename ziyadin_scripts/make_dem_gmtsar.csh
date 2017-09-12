#!/bin/csh  -f
#
#
# Ziyadin Cakir, March 2016

if ($#argv < 2) then
echo ""
echo ""
echo " enter config_file, swath number(s), [simulate = 1 or no = 0]"
echo " for swaths 1 without simulation"
echo " ex:$0 config.T123 1  "
echo ""
echo " for swaths 1 and 2 witout simulation"
echo " ex:$0 config.T123 1,2" 
echo ""
echo " for all swaths with simulation"
echo " ex:$0 config.T123 1,2,3 1 "
exit 1
endif


set config_file = config_sinop_asc.gmtsar
set config_file = $1
if ( ! -e $config_file) then
 echo ""
 echo "$config_file does not exist\!\!"
 echo ""
 exit 1
endif
#
#set swath = `echo $2 | cut -c2-2`
set swath =  $2 
set sim = $3


# set the senor; ENVISAT, SENTINEL, TSX
set sensor = `grep "sensor = " $config_file| awk '$1 !~/#/ {if ($2 = "=") print $0}'  | awk 'END {print $3}' `
# data path
# set full path to the working directory 
set workdir = `grep "workdir = " $config_file| awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk ' END {print $3}' | sed s'/\[ //'`; 
echo " workdir = $workdir "
# name of the working directory; usually track number, region etc
set name = $workdir:t
if ($name == "") then
 set name = $workdir:t
endif

# set dem file
set dem_file = `grep "dem_file = " $config_file| awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk ' END {print $3}' | sed s'/\[ //'`; 
if (! -e $dem_file) then
   echo ""
   echo "$dem_file does not exist"
   echo ""
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
   exit 1
endif
echo " dem_file = $dem_file"

# set dem file
set fault_file = `grep "fault_file = " $config_file| awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk ' END {print $3}' | sed s'/\[ //'`; 
if (-e $fault_file) then
 echo " fault_file = $fault_file"
endif

# set the PS type
set PS = `grep "PS = " $config_file  | awk '$1 !~/#/ {if ($2 = "=")  print $0 }'| awk ' END {print $3}' `

# set the master date
set master = `grep "master = " $config_file  | awk '$1 !~/#/ {if ($2 = "=" && $3  > 1000) print $0}'| awk ' END {print $3}' `

set partition = `grep "partition = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
if ($partition == "") then
 echo " ERROR\!\!"
 echo " partition   is not set"
 echo ""
 set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
 kill $PPID
 exit 1
endif
echo " partition = $partition"
#
set account = `grep "account = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
if ($account == "") then
 echo " ERROR\!\!"
 echo " account  is not set"
 echo ""
 set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
 kill $PPID
 exit 1
endif
echo " account = $account"
#
set nodes = `grep "nodes = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
if ($nodes == "") then
 set nodes = 1
endif
echo  " nodes = $nodes"
#
set ntask = `grep "ntask = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
if ($ntask == "") then
 set ntask = 1
endif
echo " ntask = $ntask"
#
set time_limit = `grep "time_limit = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
if ($time_limit == "") then
 set time_limit = 04:00:00
endif
echo " time_limit = $time_limit"
#
if ( $PS == "SM") then
 if (! -e $workdir/SLC/$master) then
   echo ""
   echo "$master $workdir/SLC/$master does not exist"
   echo ""
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
   exit 1
 endif
 echo " master = $master"
endif
#
if ($sensor == "") then
  echo ""
  echo "ERROR!  set sensor type"
  echo ""
  set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
  kill $PPID
  exit 1
endif
echo " sensor = $sensor" 
#
if ($workdir == "") then
 echo ""
 echo "ERROR!  set workdir path"
 echo ""
 set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
 kill $PPID
 exit 1
endif

#echo " working directory = $workdir"
#echo " sensor = $sensor"
if ($sensor == "SENTINEL") then 
echo " swath = $swath"
endif
if ($sim == 1) then
 echo " dem simulation = yes"
else
 echo " dem simulation = no"
endif
 
echo " cropping the dem"
#echo " mak the dem file"
# wait a lit bit to check the paramters printed to screen
sleep 10s
######################################################################

# create topo dir if it does not exist
if (! -e $workdir/topo) then
\mkdir $workdir/topo
endif

# plot frames

if ($sensor == "SENTINEL") then 
  if ($master == "") then
   # no master defined. so find the folder with maximum number of frames
   set nf = "" 
   foreach f ( `\ls -d   $workdir/SLC/2* ` ) 
    set nf = ($nf `\ls $f/*tiff | wc -l`  $f)
   end
   set master = `echo $nf | xargs -n 2 | sort -n | awk -F"/" 'END {print $NF}'`
   #
  endif
  cd $workdir/SLC/$master
  if (! -e $name.kml) then
   # make kml and plot
   # get the frame coordinates
   set lo = `grep longitude $workdir/SLC/$master/*.xml | awk -F'[<|>]' '{print $3}' | gmtinfo -C | awk '{printf "%2.2f %2.2f\n", $1-0.2,$2+0.2}'`
   set la = `grep latitude $workdir/SLC/$master/*.xml |  awk -F'[<|>]' '{print $3}' | gmtinfo -C | awk '{printf "%2.2f %2.2f\n", $1-0.2,$2+0.2}'`
   # 
   # make kml file for each subswath
   set arr = ""
   foreach f (`\ls s*[4-6].xml`)
    #set d = (`echo $f:r | awk -F- '{print $NF}'`)
    #if ($d  != "$arr[$#arr]") then
     if (-e  $fault_file) then
      plot_S1_frames.csh $f $fault_file
     else
      plot_S1_frames.csh $f 
     endif
    #echo $d
    #set arr = ($arr $d)
    #endif
   end 
   # merge alll the kml files
   if (-e $name.kml) then
    \rm $name.kml
   endif 
   mergekml s*kml $name.kml
   #
   # plot 
   # get  region
   set r = $lo[1]/$lo[2]/$la[1]/$la[2]
   set im = ${name}_frames.ps
   pscoast -Df -S120 -R$r -JM12 -W -B1 -B+t$name -K -P> ! $workdir/$im
   if (-e  $fault_file) then
    psxy -O -K -R -J $fault_file >> $workdir/$im
   endif
   kml2gmt $workdir/SLC/$master/$name.kml | psxy  -O -R -J -W >> $workdir/$im
    if (`which gv | wc -l` > 0) then
     gv $workdir/$im &
    endif
  endif
 endif
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

# skip make topo_ra if not requested
goto atla
################################################ simulation #####################################
makesim:
echo ""
echo "DEM2TOPO_RA.CSH - START"
 cat << son > !  ${workdir}/topo/1_sim.sh
#!/bin/csh -f
cd ${workdir}/topo
set prm = \`find ${workdir} -type f -name "*$master*ALL*.PRM" | grep F$swath| awk 'NR==1 {print \$1}'\`
\\cp  \$prm master.PRM 
ln -fs \$prm:r.LED . 
dem2topo_ra.csh master.PRM dem.grd 
son
 #SBATCH --mail-type=ALL
 cat << son > !  ${workdir}/topo/kuyruk_sim.sh
#!/bin/bash -f
#SBATCH -p $partition 
#SBATCH -A $account  
#SBATCH -J ${name}_F${swath}_sim
#SBATCH -N $nodes
#SBATCH -n $ntask
#SBATCH --array=1-1
#SBATCH --time=$time_limit
#SBATCH --mail-user=ziyadin.cakir@yandex.com
#SBATCH --output=sim-%j.out
#SBATCH --error=sim-%j.err
csh ${workdir}/topo/\$SLURM_ARRAY_TASK_ID"_sim.sh"
son
 #
 # check the queue before sending
 check_queue.csh  ${name}_F${swath}_sim 1
 #
 # go to swath dir 
 cd ${workdir}/topo
 #
 # sent the job to queue
 sbatch ${workdir}/topo/kuyruk_sim.sh
 # check the queue at every minute and make sure all done
 check_queue.csh  $name 5
echo "DEM2TOPO_RA.CSH - END"
atla:
#
echo ""
echo " the dem file:"
grdinfo ${workdir}/topo/dem.grd -C
# 



