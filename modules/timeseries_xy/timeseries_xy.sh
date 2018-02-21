#!/bin/bash

######################################################################
#
# Sample a series of grid values through a stack for a given xy
# cooridnate.
#
# Requires a file 'timeseries_xy.config' in the OSARIS config folder. 
# Get startet by copying the config_template file from the templates 
# folder and fit it to your setup.
#
# David Loibl, 2018
#
#####################################################################

if [ ! -f "$OSARIS_PATH/config/timeseries_xy.config" ]; then
    echo
    echo "Cannot open timeseries_xy.config in the OSARIS config folder. Please provide a valid config file."
    echo
else
    TS_start_time=`date +%s`

    source $OSARIS_PATH/config/timeseries_xy.config   

    mkdir -p $work_PATH/timeseries_xy
    cd $work_PATH/timeseries_xy

    for coordset in ${TS_coordinates[@]}; do
	echo $coordset >> TS_sample_locations.xy
    done


    cd $TS_input_PATH
       
    folders=($( ls -d */ ))
    for folder in "${folders[@]}"; do
	folder=${folder::-1}

	for grdfile in ${TS_gridfiles[@]}; do 
	    values=$( gmt grdtrack $work_PATH/timeseries_xy/TS_sample_locations.xy -G$folder/$grdfile )
	    # echo "Gridfile: $grdfile"
	    # echo "Values: $values"	
	    # echo "Gridfile: $grdfile, Values: $values" >> $output_PATH/timeseries_string_${grdfile}.csv	
	    # echo "${grdfile:10:8},${grdfile:33:8},${value:16}"  >> $output_PATH/timeseries_string_${grdfile}.csv
	    for read value; do		
		csv_string=$( echo $value | awk '{ print $1,$2,$3 }')
		echo "$folder,$csv_string" >> $output_PATH/timeseries_${grdfile}.csv
	    done <<< $values
	done
    done



    TS_end_time=`date +%s`
    TS_runtime=$((TS_end_time - TS_start_time))

    printf 'Elapsed wall clock time:\t %02dd %02dh:%02dm:%02ds\n' $(($TS_runtime/86400)) $(($TS_runtime%86400/3600)) $(($TS_runtime%3600/60)) $(($TS_runtime%60)) >> $output_PATH/Reports/timeseries_xy.report


fi
