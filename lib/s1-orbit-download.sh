#!/usr/bin/env bash

# wget -nH -l1 --no-parent --no-check-certificate -nc --reject-regex '\?' -r -nd -R *.txt,*.html* -P $1 https://s1qc.asf.alaska.edu/aux_poeorb/

if [ "$2" -ge 1 ]; then
     last_page=$2
else
     last_page=1
fi

for page in `seq 1 $last_page`; do
     wget -nH -l1 --no-parent --no-check-certificate -nc --reject-regex '\?' -r -nd -R *.txt,*.html* -P $1 https://qc.sentinel1.eo.esa.int/aux_poeorb/?page=$page
done



