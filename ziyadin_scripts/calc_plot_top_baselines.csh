#!/bin/csh  -f
#
# Script for baseline plot for TOPS data
#
# Ziyadin Cakir, March 2016

if ($#argv < 1) then
echo ""
echo ""
echo "enter config_file [list] [2]"
echo ""
echo "ex:$0 config.T43  2 [2= plot only]"
echo "ex:$0 config.T43  list.txt [file listing master and slave dates]" 
set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
kill $PPID
exit 1
endif

#
set config_file = $1

if ( ! -e $config_file) then
 echo ""
 echo "$config_file does not exist\!\!"
 echo ""
 set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
 kill $PPID
 exit 1
endif
 
 # orbit directory for Sentinel# last bit is used in case there is "/" after at the end of the path
set orbdir = `grep "orbdir = " $config_file| awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk ' END {print $3}'| sed s'/\[ //'`
# path to data 
set data = `grep "data = " $config_file| awk '$1 !~/#/ {if ($2 = "=") print $0}'  | awk 'END {print $3}'| sed s'/\[ //' `
# set full path to the working directory 
set workdir = `grep "workdir = " $config_file| awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk ' END {print $3}'| sed s'/\[ //'`; 
# name of the working directory; usually track number, region etc
set name = $workdir:t
if ($name == "") then
 set name = $workdir:t
endif
# set event date
set core = `grep "core = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
if ($core == "") then
 set core = 1
endif
# path to data 
set event = `grep "event = " $config_file| awk '$1 !~/#/ {if ($2 = "=") print $0}'  | awk 'END {print $3}'| sed s'/\[ //' `

# set the master date
set master = `grep "master = " $config_file  | awk '$1 !~/#/ {if ($2 = "=" && $3  > 1000) print $0}'| awk ' END {print $3}' `
set masterd = `grep "master = " $config_file  | awk '$1 !~/#/ {if ($2 = "=" && $3  > 1000) print $0}'| awk ' END {print $3}' ` 
# set perp and temporal baselines
#  Time difference in days for small baseline pairs
set dt = `grep "dt = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
#  Baseline difference in m for small baseline pairs
set db = `grep "db = "  $config_file| awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
set script = $0

if ($orbdir == "" ) then
   echo ""
   echo " ERROR\!\!  orbit dir  must be set"
   echo ""
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
   exit 1
  endif
    echo " orbit directory = $orbdir"
endif
 #
if ($workdir == "") then
 echo ""
 echo "ERROR\!\! set workdir path"
 echo ""
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
 exit 1
endif

#
if ($master == "") then
 set master = `\ls SLC | awk 'NR==1 {print $0}'`
endif 


#echo " name = $name                         (used in screen name)"
echo " working directory = $workdir"
echo " master date = $master"
echo " event date = $event"
# wait a lit bit to check the parameters printed to screen
echo ""
echo " check the parameters above"
echo ""
sleep 10s
if ($2 == 2) then
 goto plot
endif
#goto baselines
###############################################################################
cd $workdir
## check if SM or SB is set and create ifg list and directoris
 if (! -e SLC/$master) then
   echo ""
   echo "master $workdir/SLC/$master does not exist"
   echo ""
   set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
   kill $PPID
  exit 1
 endif
 if (-e $workdir/SLC/baselines) then
  \rm -r $workdir/SLC/baselines
 endif
  mkdir -p $workdir/SLC/baselines
 
 # go to InSAR directory
 cd $workdir/SLC/baselines
# if ifg list exists use it otherwise get it from PS folder or workdir
 set list = $2
  if ($list == "") then
  \ls -d $workdir/SLC/[1,2]*[0-9] | awk -F"/" '{print $(NF)}' | sed "/$master/ d" | awk '{print '$master',$1}'> ! int.list
  else
   if (-e $workdir/SLC/$list) then
    \cp $workdir/SLC/$list .
   else 
    echo "$workdir/SLC/$list does not exist"
    set PPID = `ps -ef | awk -v pid="$$" '{if ($2 == pid) {print $3}}'`
    kill $PPID
    exit 1
   endif
 endif
 # 
# loop for ifg number 
set n = 1
set i = 4
foreach f (`cat int.list | awk 'NF > 1 {print $1"_"$2}'`) 
 set slave  = (`echo $f | awk -F_ '{print $2}'`)
 set master = (`echo $f | awk -F_ '{print $1}'`)
  
 # see if master of slave folder is missing
  if (! -e $workdir/SLC/$master || ! -e $workdir/SLC/$slave) then
   echo ""
   echo "   CHECK OUT $master or $slave does not exist \!\!"
   echo "                 skipping"
   goto atla
  endif
  #
   if (`find $workdir/SLC/$master/ -name "*-00${i}.tiff" | wc -l` >= 1) then
     set imM  = $workdir/SLC/$master/*-00${i}.tiff
   else
     set imM = ""
   endif 
    # xml file
    if (`find $workdir/SLC/$master/ -name "*-00${i}.xml" | wc -l` >= 1) then
     set xM   = $workdir/SLC/$master/*-00${i}.xml
    else 
     set xM = ""
    endif
     # slave files
    if (`find $workdir/SLC/$slave/ -name "*-00${i}.tiff" | wc -l` >= 1) then
     set imS  = $workdir/SLC/$slave/*-00${i}.tiff
    else
     set imS = ""
    endif
   if (`find $workdir/SLC/$slave/ -name "*-00${i}.xml" | wc -l` >= 1) then
     set xS   = $workdir/SLC/$slave/*-00${i}.xml
    else 
     set xS = ""
    endif
   
      if ( $xM[1] == "" | $xS[1] == "" | $imM[1] == "" | $imS[1] == "" ) then
     echo ""
     echo "  skipping $master"_"$slave"_F"$i, master or slave file is missing"
     echo "  check swath number"
     goto atla
    endif
 
    set mSAT = `echo $xM:t | cut -c1-3 | tr '[:lower:]' '[:upper:]'`
    set sSAT = `echo $xS:t | cut -c1-3 | tr '[:lower:]' '[:upper:]'`
    #
     # get the hour of aquition
     set saatM = `echo $xM:t:r | awk -Ft '{print substr($2,1,6)}'`
     set saatS = `echo $xS:t:r | awk -Ft '{print substr($2,1,6)}'`
     # subtract 1 day from the dates
     set dM = `date -d "$master - 1 day" +%Y%m%d`
     set dS = `date -d "$slave  - 1 day" +%Y%m%d`
 
     # find the orbit file for the master 
      set orbM = `\ls  -la  $orbdir/aux_poeorb/${mSAT}* | awk  '{print $(NF)}'| awk -F"/" '{print $(NF) }'| awk -F_ '{print substr($7,2,8),substr($8,1,8), $0}' | awk ' {if ($1 == '$dM' ) print $3}'| awk 'NR==1 {print $0}' `
     # if there is no precise orbit (which is available atfer 3 weeks) get the  resituated orbit available within 3 hours after the acquisition
     if ($#orbM == 0) then
      # get full acquisition time of the master 
      set at = `ls $workdir/SLC/$master/*-00${i}.xml | awk -F"/" 'NR==1 {print substr($NF,16,8)  substr($NF,25,6)}'`
      set orbM = `\ls -l  $orbdir/aux_resorb/${mSAT}* | awk  '{print $(NF)}'| awk -F"/" '{print $(NF) }'| awk -F_ '{print substr($7,2,8),substr($8,1,8), $0}' | awk '{if ($1 == ('$master') ) print $3}' | awk -F_ '{print substr($7,2,8) substr($7,11,6),substr($8,1,8) substr($8,10,6), $0}' | awk '{if ($2 >= '$at' && $1 <= '$at' ) print $0}' | awk 'NR==1 {print $3}' `
     endif
       
       # find the orbit file for the slave
      set orbS = `\ls  -la  $orbdir/aux_poeorb/${sSAT}* | awk  '{print $(NF)}'| awk -F"/" '{print $(NF) }'| awk -F_ '{print substr($7,2,8),substr($8,1,8), $0}' | awk '{if ($1 == '$dS' ) print $3}' | awk 'NR==1 {print $0}' `
      # if there is no precise orbit (which is available atfer 3 weeks) get the  resituated orbit available within 3 hours after the acquisition
     if ($#orbS == 0) then
      # get full acquisition time of the slave 
      set at = `ls $workdir/SLC/$slave/*-00${i}.xml | awk -F"/" 'NR==1 {print substr($NF,16,8)  substr($NF,25,6)}'`
      set orbS = `\ls -l  $orbdir/aux_resorb/${sSAT}* | awk  '{print $(NF)}'| awk -F"/" '{print $(NF) }'| awk -F_ '{print substr($7,2,8),substr($8,1,8), $0}' | awk '{if ($1 == ('$slave') ) print $3}' | awk -F_ '{print substr($7,2,8) substr($7,11,6),substr($8,1,8) substr($8,10,6), $0}' | awk '{if ($2 >= '$at' && $1 <= '$at' ) print $0}' | awk 'NR==1 {print $3}' `    
     endif
  
      # check if orbit files exist
     if ( $orbM == "" | $orbS == ""  ) then
      echo ""
      echo "  skipping $master"_"$slave"_"$i, master or slave orbits is missing"
      echo ""
      goto atla
     else
       if ($n == 1 ) then
         ln -sf $orbdir/*/$orbM $workdir/SLC/baselines/
         ln -sf $xM $workdir/SLC/baselines/
         ln -sf $imM $workdir/SLC/baselines/
         echo $xM:t:r | awk '{for (i=1; i <= NF; i++) printf"%s:", $i }' > !  $workdir/SLC/baselines/frames.in
         echo $orbM >> $workdir/SLC/baselines/frames.in
          
         ln -sf $orbdir/*/$orbS $workdir/SLC/baselines/
         ln -sf $xS $workdir/SLC/baselines/
         ln -sf $imS $workdir/SLC/baselines/
         echo $xS:t:r | awk '{for (i=1; i <= NF; i++) printf"%s:", $i }' >> $workdir/SLC/baselines/frames.in
         echo $orbS >> $workdir/SLC/baselines/frames.in
       else 
         ln -sf $xS $workdir/SLC/baselines/
         ln -sf $imS $workdir/SLC/baselines/
         ln -sf $orbdir/*/$orbS $workdir/SLC/baselines/
         echo $xS:t:r | awk '{for (i=1; i <= NF; i++) printf"%s:", $i }' >> $workdir/SLC/baselines/frames.in
         echo $orbS >> $workdir/SLC/baselines/frames.in
       endif
    endif
echo $slave
@ n ++
atla:
end

################  prepare the baseline table
baselines:
cd  ${workdir}/SLC/baselines
set list = frames.in
# first line is the super-master, all images aligned to it
set master = `awk -F: 'NR==1 {print $1}' $list | awk '{ print toupper(substr($1,1,3))substr($1,16,8)"_"substr($1,25,6)"_F"substr($1,7,1)}'` 
set mmaster = `awk -F: 'NR==1 {print $1}' $list | awk '{ print toupper(substr($1,1,3))substr($1,16,8)"_ALL_F"substr($1,7,1)}'`
# clean up a little bit
rm -f *.PRM* *.SLC *.LED tmp*
rm -f *dat *sh *gmt

if (`find ${workdir}/SLC/baselines/ -name "*sh" | wc -l` > 0) then
 \rm  ${workdir}/SLC/baselines/*sh
 \${workdir}/SLC/baselines/*out
 \${workdir}/SLC/baselines/*err
endif

\rm ${workdir}/SLC/baselines/*PRM
set n = 1 
# loop over all the acquisitions
foreach line (`awk '{print $0}' $list`)
cat <<son> ! ${workdir}/SLC/baselines/${n}_baseline.sh
#!/bin/csh -f
# record the first one as the stem_master
 cd $workdir/SLC/baselines
 set stem_master = \`echo $line | awk -F: '{print \$1}' | awk '{ print toupper(substr(\$1,1,3))substr(\$1,16,8)"_"substr(\$1,25,6)"_F"substr(\$1,7,1)}'\`
 set m_stem_master = \`echo $line | awk -F: '{print \$1}' | awk '{ print toupper(substr(\$1,1,3))substr(\$1,16,8)"_ALL_F"substr(\$1,7,1)}'\`
 set image = \`echo $line | awk -F: '{print \$1}'\`
 set orbit = \`echo $line | awk -F: '{print \$NF}'\`
 # generate prms and leds
 make_s1a_tops \$image.xml \$image.tiff \$m_stem_master 0
 ext_orb_s1a \$m_stem_master.PRM \$orbit \$m_stem_master
 # get the height and baseline info
 \\cp \$m_stem_master.PRM junk1\$stem_master
 calc_dop_orb junk1\$stem_master junk2\$stem_master 0 0
 cat junk1\$stem_master junk2\$stem_master > ! \$m_stem_master.PRM
 baseline_table_multi.csh $mmaster.PRM \$m_stem_master.PRM > ! ${n}_b.dat
 baseline_table_multi.csh $mmaster.PRM \$m_stem_master.PRM GMT > ! ${n}_t.gmt
son
#
chmod +x  ${workdir}/SLC/baselines/${n}_baseline.sh
@ n ++
end

set m = `\ls ${workdir}/SLC/baselines/*baseline.sh | wc -l`
# counter for redoing 
set t = 1
disp1:
# sbatch file 40 at a tie
set fst = 1
set j = 1
# loop for $#core jobs at a time 
set core = 20
while ($fst <= $m) 
@ lst = $fst + $core - 1
#
if ($lst > $m) then
set lst = $m
endif
# 
#SBATCH --mail-type=ALL
cat << son > !  ${workdir}/SLC/baselines/kuyruk-baseline${j}.sh
#!/bin/bash -f
#SBATCH -p levrekv2 
#SBATCH -A tbag37  
#SBATCH -J ${name}_baz
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --array=${fst}-${lst}
#SBATCH --time=04:00:00
#SBATCH --mail-user=ziyadin.cakir@yandex.com
#SBATCH --output=baz%j.out
#SBATCH --error=baz%j.err
csh ${workdir}/SLC/baselines/\$SLURM_ARRAY_TASK_ID"_baseline.sh"
son
#
# check the queue before sending
check_queue.csh  $name 1
#
# go to swath dir 
cd ${workdir}/SLC/baselines
#
# sent the job to queue
sbatch ${workdir}/SLC/baselines/kuyruk-baseline${j}.sh
# check the queue at every minute and make sure all done
check_queue.csh  $name 1
#
@ fst = $fst + $core
@ j = $j + 1

end

\rm junk*
 
#
foreach f (`\ls [0-9]*b.dat | sort -g`)
 cat $f >>!  baseline_table.dat
end
foreach f (`\ls [0-9]*t.gmt | sort -g`)
 cat $f >>!  table.gmt
end   
##
awk '{print $2,$5,substr($1,4,8)}' baseline_table.dat | awk ' {if (NF==3) print $0}'  > ! baselines.dat
\cp baselines.dat  $workdir
awk '{print 2014+$1/365.25,$2,substr($7,6,6)}'  table.gmt | awk ' {if (NF==3) print $0}' > !  text

###################  plot baselines   ################################
plot:
######################################################################
# go to InSAR directory
cd $workdir/SLC/baselines
 
if ($db == "" || $dt == "") then
 echo ""
 #echo -e "set temporal (dt) and perpendicular (db) baselines in day and meter"
 echo " temporal (dt) and perpendicular (db) baselines are not set; plotting baseliens only "
 goto SM
endif

set r = `awk '{if ($2 < 1000 && $2 > -1000 ) print $0}' baselines.dat  | gmtinfo -C | awk '{print substr($5,1,4)"-" substr($5,5,2)"-" substr($5,7,2), substr($6,1,4)"-" substr($6,5,2)"-" substr($6,7,2),$3-20,$4+20}'` 
set Bp = `echo $r[3] $r[4] | awk '{print int(($2-$1)/4)}'`
 
# enlarge time range for the plot
set d1 = `date -d "$r[1] - 8 weeks" --rfc-3339=date`
set d2 = `date -d "$r[2] + 8 weeks" --rfc-3339=date`

set noi = `wc -l baselines.dat`
#plot
gmtset FORMAT_DATE_IN yyyymmdd PS_MEDIA A4 PROJ_LENGTH_UNIT cm FONT_ANNOT_PRIMARY 12 FONT_TITLE 18	
 set mod = `grep pass *${masterd}*.xml | awk -F">|<" ' NR == 1 {print $3}'`

set nl = 1
  awk '{print $3,$2+7, substr($3,7,2)substr($3,5,2)substr($3,3,2)}' baselines.dat | pstext -R${d1}T/${d2}T/$r[3]/$r[4] -JX18.5/12.5 -K > ! baselines_sb.ps 
 \rm -f make_sb_ifg.list make_event_ifg.list sb.net event.net;
 foreach m ( `awk '{print $1"_"$2"_"$3}' baselines.dat ` )
  foreach s ( `awk '{print $1"_"$2"_"$3}' baselines.dat ` )
       set mdate =  ` echo $m | awk -F_ '{print $3}'`
       set sdate =  ` echo $s | awk -F_ '{print $3}'`
       set md =  ` echo $m | awk -F_ '{print $3}' | xargs date  +%s -d | awk '{printf"%4.0f",$1/86400}'`
       set sd =  ` echo $s | awk -F_ '{print $3}' | xargs date  +%s -d | awk '{printf"%4.0f",$1/86400}'`     
       set mb =  ` echo $m | awk -F_ '{print $2}'`
       set sb =  ` echo $s | awk -F_ '{print $2}'`
       set ddif =  ` echo $md $sd | awk  '{print $2-$1}'`
       if ($#event > 0) then 
        set ed =  ` echo $event | xargs date  +%s -d | awk '{printf"%4.0f",$1/86400}'`     
      #  if ($md < $sd & ($sd - $md) < $dt & $md < $ed & $sd > $ed) then
          if ( $md <= $ed  &&  $sd >= $ed && $ed - $md <= $dt && $sd - $ed <= $dt) then
            set db0 = `echo $mb $sb | awk '{printf"%3.0f", sqrt(($1-$2)^2)}'`
             if ($db0 < $db) then
              set bdiff = `echo $mb $sb | awk '{printf"%3.0f", $1-$2}'`
              echo $mdate $sdate $bdiff >>! make_event_ifg.list
              echo $mdate  $mb | awk '{print $1,$2}' >>! event.net
              echo $sdate  $sb | awk '{print $1,$2}' >> event.net
              echo ">" >> event.net
              psxy event.net -R -J -K -O  -W1,green >> baselines_sb.ps
             endif
         endif
       endif
       if ($md < $sd & $sd - $md < $dt) then
        set db0 = `echo $mb $sb | awk '{printf"%3.0f", sqrt(($1-$2)^2)}'`
         if ($db0 < $db) then
          set bdiff = `echo $mb $sb | awk '{printf"%3.0f", $1-$2}'`
          echo $mdate $sdate $bdiff >>! make_sb_ifg.list
          echo $mdate  $mb | awk '{print $1,$2}' >>! sb.net
          echo $sdate  $sb | awk '{print $1,$2}' >> sb.net
          echo ">" >> sb.net
         endif
       endif
  end
   if (`expr $nl % 5` == 0) then
    echo $nl
   endif
   @ nl = $nl + 1
 end
 
 if (-e  event.net) then
   \cp make_event_ifg.list  $workdir
  # plot the net
   psxy event.net -R -J -K -O  -W1,green >> baselines_sb.ps
  # get number of ifg
  set ni = `wc -l event.net | awk '{print $1/3}'`
 else
   \cp make_sb_ifg.list  $workdir
  # plot the net
  psxy sb.net -R -J -K -O  -W >> baselines_sb.ps
 #  # get number of ifg
 set ni = `wc -l sb.net | awk '{print $1/3}'`
endif

# plot orbits with very large baselines due to some kind of error I do not know 
# awk '{if ($2 > 1000 || $2 < -1000 ) print $3,0}' baselines.dat | psxy -R -J -Sc.3 -Gblue -W -K -O >> baselines_sb.ps

# plot orbits
 awk '{print $3,$2}' baselines.dat |  psxy -R -J -Sc.3 -Gred -W -Bs1Y/${Bp} -Bp3o/${Bp}:"_|_ baseline (m)"::." $ni interferos \(db=$db m; dt=$dt days)  $noi[1] $mod S1 images on $name":  -K -O >> baselines_sb.ps

#plot event date
if ($event != "") then
 echo $event | awk '{print $1,'$r[3]';print $1,'$r[4]'}'  | psxy  -R -J  -O -K -W3,blue >>  baselines_sb.ps
\cp make_event_ifg.list ../../
endif

# plot quick look image
#if ($sensor == "SENTINEL") then
 # see if the images are asc or desc
 # set mod = `grep pass *${master}*.xml | awk -F">|<" ' NR == 1 {print $3}'`
# if ($mod == Descending) then
  #convert $data/*${master}*/preview/quick-look.png -transpose -rotate 90 x.png
 # psimage x.png -X15 -O -W3i -M -K >> baselines_sb.ps
# else
 # convert $data/*${master}*/preview/quick-look.png -transpose -rotate 270 x.png
 # psimage x.png -X15 -O -W3i -M -K >> baselines_sb.ps
# endif
#endif

echo "" | psxy -R -O -W -J >>    baselines_sb.ps

#gv -rotate -90 baselines_sb.ps &

 #\rm *PRM *LED text*

 SM:
# plot single master pairs
awk '{print $3,$2+7, substr($3,7,2)substr($3,5,2)substr($3,3,2)}' baselines.dat | pstext -R${d1}T/${d2}T/$r[3]/$r[4] -JX21.5/15 -K > ! baselines_sm.ps 
awk '{print $3,$2}' baselines.dat |  psxy -R -J -Sc.3 -Gred -W -Bs1Y/${Bp} -Bp3o/${Bp}:"_|_ baseline (m)"::." $noi[1] $mod S1  images on $name":  -K -O >> baselines_sm.ps
grep $master baselines.dat | awk '{print $3,$2}'| psxy -Sa0.5 -Gblue -R -J -K -O  -W >> baselines_sm.ps
grep $master baselines.dat | awk '{print $3,$2+7, substr($3,7,2)substr($3,5,2)substr($3,3,2)}'  | pstext -R${d1}T/${d2}T/$r[3]/$r[4] -Wblue -JX18.5/12.5 -F+f12p,Helvetica-Bold,blue -K -O >> baselines_sm.ps 
echo "" | psxy -R -O -W -J >>    baselines_sm.ps

#gv -rotate -90 baselines_sm.ps &
\cp baselines_sb.ps baselines_sm.ps baseline_table.dat $workdir
echo ""
echo " baselines are plotted"
echo " see  baselines_sb.ps and  baselines_sm.ps under $workdir"
echo ""
