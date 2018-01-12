# Raw concept

# Coordinates should come from config file

echo "73.98989,42.1707" > sample_location4.xy

for grdfile in $( ls *.grd ); do value=$( gmt grdtrack sample_location4.xy -G$grdfile ); echo "${grdfile:10:8},${grdfile:33:8},${value:16}"  >> corr_profile_Golubin_PS.csv; done
