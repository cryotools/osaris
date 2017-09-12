#!/bin/csh -f

if ($#argv < 4) then
 echo give insar_dir, stamps_swath, region_cut and phase.grd or display_amp.grd
 exit 1
endif

set insar_dir = $1
set stamps_swath = $2; echo "stamps_swath $stamps_swath"
set region_cut = $3 ; echo "region_cut $region_cut"
set file = $4; echo " file to plot is $file"
set workdir = $cwd 
if (`find  ${workdir} -name  $file | grep $stamps_swath | wc -l ` == 0) then
 echo "there is no $file"
 exit 1
endif

gmtset PROJ_LENGTH_UNIT = cm
gmtset PS_MEDIA = A4
set B = `echo $region_cut | awk -F"/" '{if ((($2-$1)/5) > 1000) x = substr(int(($2-$1)/5),1,1)"000"; else x = substr(int(($2-$1)/5),1,2)"0"; if ((($4 - $3)/5) > 1000) y = substr(int(($4-$3)/5),1,1)"000";else y = substr(int(($4-$3)/5),1,2)"0"; print x,y, x/2, y/2}'`
set ratio = 4
set rr = `echo  $region_cut | awk -F"/" '{print (($2-$1)/(($4-$3)*'$ratio'))}'`
if ( `echo $rr | awk '{ if ($1 > 1 ) print 1 ;else print 0}'` == 1 ) then
 set jx = 9
 set jy = ` awk ' BEGIN {print  '$jx' / '$rr' }'`
else
 set jy = 18
 set jx = ` awk ' BEGIN {print '$rr' * '$jy' }'`
endif
set boundR = $B[1]f$B[3]
set boundA = $B[2]f$B[4]
set scale = -JX$jx/$jy 


if ( `echo $file  | grep phase | wc -l` > 0) then
 set pal = phase.cpt
else if  ( `echo $file  | grep amp | wc -l` > 0) then
 set pal = display_amp.cpt
else if ( `echo $file  | grep corr | wc -l` > 0) then
 set pal = corr.cpt
 endif


set n = 1
foreach f ( `find ${workdir} -name $file | grep $stamps_swath` )  
echo $f:h:h:h:h:t
cat <<son> ! ${workdir}/${insar_dir}/kuyruk/${stamps_swath}/${n}_display.sh
#!/bin/csh 
cd $f:h
gmt grdimage $f:t -R$region_cut $scale -B"$boundR":Range:/"$boundA":Azimuth:WSen -C$pal  -Y3 -P -Q -Vq > ! $f:t:r_cut.ps
gmt ps2raster $f:t:r_cut.ps  -E72 -TG -P -S -V  -F$f:t:r_cut.png 
cd $workdir
son
@ n = $n + 1
end

set name = $cwd:t
echo ${workdir} $stamps_swath
set j =  `find  ${workdir} -name  $file | grep $stamps_swath | wc -l `
# sbatch file 20 at a time
set core = 20
set k = 1
set fst = 1
# loop for $#core jobs at a time 
while ($fst <= $j) 
@ lst = $fst + $core - 1
#
if ($lst > $j) then
 set lst = $j
endif


cat << son > !  ${workdir}/${insar_dir}/kuyruk/${stamps_swath}/kuyruk_display$k.sh
#!/bin/bash -f
#SBATCH -p levrekv2 
#SBATCH -A tbag37  
#SBATCH -J $cwd:t_display
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --array=${fst}-${lst}
#SBATCH --time=00:45:00
#SBATCH --mail-user=ziyadin.cakir@yandex.com
#SBATCH --output=display_%j.out
#SBATCH --error=display_%j.err
csh ${workdir}/${insar_dir}/kuyruk/${stamps_swath}/\$SLURM_ARRAY_TASK_ID"_display.sh"
son
#
# check the queue before sending
check_queue.csh  $name 1
#
# go to swath dir 
cd ${workdir}/${insar_dir}/kuyruk/${stamps_swath}
#
# sent the job to queue
sbatch ${workdir}/${insar_dir}/kuyruk/${stamps_swath}/kuyruk_display$k.sh
#
# check the queue at every minute and make sure all done
check_queue.csh  $name 1
#

@ fst = $fst + $core
@ k = $k + 1
end


