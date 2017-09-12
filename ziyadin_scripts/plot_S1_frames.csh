#!/bin/csh -f
if ($#argv < 1) then
 echo ""
 echo " give an input xml file"
 echo " $0 xxx.xml"
 echo 
 exit 1
endif

if (! -e $1) then
echo "$1 does not exist"
endif


set f = $1 
set fault_file = $2
set kml = $f:r.kml 
set t = ` echo $f:r | awk -F- '{print "F"$NF}'` 

# get min max of x
set x13 = `grep longitude $f | awk -F'[<|>]' '{print $3}' | gmtinfo -C | awk '{printf"%2.11f %2.11f\n",$1/10,$2/10}' | awk '{print substr($1,1,10),substr($2,1,10) }' `
# get y of xmin 
set rn = `grep -n  $x13[1] $f  |awk -F: '{print $1-1}'`
set y1 = `awk '{ if (NR=='${rn}') print $0}' $f |  awk -F'[<|>]' '{print $3}'`
# get y of xmax 
set rn = `grep -n  $x13[2] $f  |awk -F: '{print $1-1}'`
set y3 = `awk '{ if (NR=='${rn}') print $0}' $f |  awk -F'[<|>]' '{print $3}'`


# get min max of  y
set y24 = `grep latitude $f | awk -F'[<|>]' '{print $3}' | gmtinfo -C | awk '{printf"%2.11f %2.11f\n",$1/10,$2/10}' | awk '{print substr($1,1,10),substr($2,1,10) }' `
# get x of ymin
set rn = `grep -n  $y24[1] $f  |awk -F: '{print $1+1}'`
set x2 = `awk '{ if (NR=='${rn}') print $0}' $f |  awk -F'[<|>]' '{print $3}'`
# get x of ymax
set rn = `grep -n  $y24[2] $f  |awk -F: '{print $1+1}'`
set x4 = `awk '{ if (NR=='${rn}') print $0}' $f |  awk -F'[<|>]' '{print $3}'`




set r = `echo $x13 $y24 | awk '{print $1*10-0.1, $2*10+0.1,$3*10-0.1,$4*10+0.1}'`

echo $x13[1] $y1 | awk '{print $1*10,$2}' > !  f.txt
echo $x2     $y24[1]| awk '{print $1,$2*10}' >> f.txt
echo $x13[2] $y3| awk '{print $1*10,$2}' >> f.txt
echo $x4     $y24[2] | awk '{print $1,$2*10}'>> f.txt
echo $x13[1] $y1 | awk '{print $1*10,$2}' >>  f.txt

pscoast -Df -S120 -R$r[1]/$r[2]/$r[3]/$r[4] -JM12 -W -B1 -B+t$t -K -P> ! $kml.ps
if ($fault_file != "") then
 psxy -O -K -R -J $fault_file >> $kml.ps
endif
psxy f.txt -O -R -J -W >> $kml.ps
#xv $kml.ps &
echo $kml.ps
sleep 1s

gmt2kml f.txt -Fp > ! $kml
\rm f.txt 

