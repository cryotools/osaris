#!/usr/bin/env bash

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

module_name="timeseries_xy"

if [ -z $module_config_PATH ]; then
    echo "Parameter module_config_PATH not set in main config file. Setting to default:"
    echo "  $OSARIS_PATH/config"
    module_config_PATH="$OSARIS_PATH/config"
elif [[ "$module_config_PATH" != /* ]] && [[ "$module_config_PATH" != "$OSARIS_PATH"* ]]; then
    module_config_PATH="${OSARIS_PATH}/config/${module_config_PATH}"    
fi

if [ ! -d "$module_config_PATH" ]; then
    echo "ERROR: $module_config_PATH is not a valid directory. Check parameter module_config_PATH in main config file. Exiting ..."
    exit 2
fi

if [ ! -f "${module_config_PATH}/${module_name}.config" ]; then
    echo
    echo "Cannot open ${module_name}.config in ${module_config_PATH}. Please provide a valid config file."
    echo
else
    # Start runtime timer
    TS_start_time=`date +%s`

    # Include the config file
    source ${module_config_PATH}/${module_name}.config


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
