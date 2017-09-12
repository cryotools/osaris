#!/bin/csh 
if ($#argv == 1) then
 set name = $1
 set duration = 3
else if ($#argv == 2) then
 set name = $1
 set duration = $2
else
 set name = `whoami | cut -c1-8`  
 set duration = 1
endif

set jq = `squeue -o "%.35j %.7i %.8u %.2t %.10M %.6D %R " | awk -F_ 'NR > 1 {printf"%s\n", $1}' | awk 'NR==1{ print $1}'`

bekle:
set nq  = `squeue -o "%.35j %.7i %.8u %.2t %.10M %.6D %R "  | grep $name | wc -l`
set npr = `squeue -o "%.35j %.7i %.8u %.2t %.10M %.6D %R "  | grep $name | awk 'NR==1{print $1}'`
if ($nq == 0) then
 goto devam
else 
  squeue -o "%.20j %.7i %.8u %.2t %.10M %.6D %R "
  sleep ${duration}m
  goto bekle
endif
devam:

