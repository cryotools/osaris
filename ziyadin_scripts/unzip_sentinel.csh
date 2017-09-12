#!/bin/csh  -f
#
#
# Ziyadin Cakir, March 2016

if ($#argv < 1) then
echo " unzip sentinele files with or without zip extension"
echo ""
echo enter config_file
echo ""
echo "ex:$0 config.sa1.gmtsar "
echo ""
exit 1
endif

set config_file = $1
if ( ! -e $config_file) then
 echo ""
 echo "$config_file does not exist\!\!"
 echo ""
 exit 1
endif

# set the senor; ENVISAT, SENTINEL, TSX
#set sensor = `grep "sensor = " $config_file| awk '$1 !~/#/ {if ($2 = "=") print $0}'  | awk 'END {print $3}' `
# data path
set data = `grep "data = " $config_file| awk '$1 !~/#/ {if ($2 = "=") print $0}'  | awk 'END {print $3}' `
# set full path to the working directory 
set workdir = `grep "workdir = " $config_file| awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk ' END {print $3}'`; 
# name of the working directory; usually track number, region etc
set name = $workdir:t
# in case there is "/" after at the end of the path
if ($name == "") then
 set workdir = `echo $workdir | sed 's#/*$##;s#^/*##'`
 set name = $workdir:t
endif
#SBATCH -N $nodes
#SBATCH -n $ntask
set nodes = `grep "nodes = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
if ($nodes == "") then
 set nodes = 1
endif
set ntask = `grep "ntask = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
if ($ntask == "") then
 set ntask = 1
endif
# set number of simultanous unzipping 
set nzip = `grep "nzip = " $config_file | awk '$1 !~/#/ {if ($2 = "=") print $0}' | awk 'END {print $3}' `
set ben = `whoami | cut -c1-8`

if ($nzip == "") then
 set nzip = 1
endif

 if ($data == "") then
  echo ""
  echo " set data path"
  echo ""
  exit 1
 endif
 
if ($workdir == "") then
 echo ""
 echo " set workdir path"
 echo ""
 exit 1
endif
echo " working directory = $workdir"
echo " data path = $data"
echo " number of simultanous unzip  = $nzip"

 #if ($sensor == "") then
  #echo ""
  #echo " set sensor type"
  #echo ""
  #exit 1
 #endif

# wait a lit bit to check the paramters printed to screen
sleep 10s
######################################################################

# go the data directory
cd $data
 
# check if data exist
if ( `find $data -name "S1[A,B]*" | wc -l` == 0 ) then
    echo ""
    echo " no data in $data\!"
    echo ""
   exit 1
endif

# get number of unzipped files
set nf = 0;set niz = 0
foreach f (`find ./ -name \*_\?\?\?\? -o -name \*.zip`)
 if (! -e $f.SAFE) then
   @ nf = $nf + 1 
   echo $f 
 endif
end

if (-e $data/queue) then
 \rm  -r $data/queue/
 mkdir $data/queue/
else
 mkdir $data/queue
endif
 
set n = 1
# unzip the file if not already unzipped
foreach im ( `find ./ -name \*_\?\?\?\? -o -name \*.zip `)
  if (! -e $im.SAFE) then
   cat <<son> ! $data/queue/${n}_unzip.sh
    cd $data
    unzip $im  | tee -a $im.log
son
@ n = $n + 1
  endif
end

set v = `find $data/queue -name "[0-9]*.sh" | wc -l` 

if ($v > 0) then
cd $data/queue
 set j = 1
 set ll = 1
 while ($ll <= $nf)
 @ s = $ll +  $nzip - 1
 if ($s > $nf) then
  set s = $nf
 endif

cat <<son > !  $data/queue/unzip.sh
#!/bin/bash
#SBATCH -p levrekv2 
#SBATCH -A tbag37  
#SBATCH -J ${name}_unzip_${j}
#SBATCH -N $nodes
#SBATCH -n $ntask
#SBATCH --array=${ll}-${s}
#SBATCH --time=01:00:00 
#SBATCH --output=unzip-%j.out
#SBATCH --error=unzip-%j.err
sh \$SLURM_ARRAY_TASK_ID"_unzip.sh" 
son
#
#
grep array *sh
echo "$ll to $s of $nf"
# check the queue before sending
check_queue.csh $ben 1
#
# sent the job to queue
sbatch unzip.sh $ben 1
check_queue.csh $ben 1

@ ll = $ll + $nzip
@ j ++
 end
else 
 echo " nothing to unzip"
endif
# check the queue 
#check_queue.csh $ben 1

#\rm -r $data/queue
cd $workdir




