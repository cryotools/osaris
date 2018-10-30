#!/usr/bin/env bash

######################################################################
#
# OSARIS modules to remove trends from series of grid data.
#
#
# David Loibl, 2018
#
#####################################################################

module_name="detrend"

if [ ! -f "$OSARIS_PATH/config/${module_name}.config" ]; then
    echo
    echo "Cannot open ${module_name}.config in the OSARIS config folder. Please provide a valid config file."
    echo
else
    # Start runtime timer
    module_start=`date +%s`

    # Include the config file
    source $OSARIS_PATH/config/${module_name}.config



    ############################
    # Module actions start here
    
    echo; echo "Starting Detrend module ..."; echo
   
    RT_work_PATH="$work_PATH/Detrend"
    RT_output_PATH="$output_PATH/Detrend"
 
    if [ ! -d "$RT_grid_input_PATH" ]; then
	echo; echo "ERROR: Directory $RT_grid_input_PATH does not exist. Exiting ..."
	check_input=0
    else	    
	cd "$RT_grid_input_PATH"
	grid_files=($( ls *.grd ))
	if [ ! -z "$grid_files" ]; then	    
	    echo "Found ${#grid_files[@]} grid files in ${RT_grid_input_PATH}."
	    check_input=1
	else
	    echo; echo "ERROR: No grid files found in $RT_grid_input_PATH. Exiting ..."
	    check_input=0
	fi
    fi

    if [ -z $RT_model ]; then
	echo "Parameter RT_model not set in config/${module_name}.config ..."
	echo "Setting RT_model to 10+r (bicubic + iterative processing)"
	RT_model="10+r"
    fi
    
    if [ "$check_input" -eq 1 ]; then
	echo "Input data looks good, initializing trend removal ..."
	mkdir -p "$RT_work_PATH"
	mkdir -p "$RT_output_PATH"

	if [ "$RT_safe_trend_files" -eq 1 ]; then
	    mkdir -p "$RT_output_PATH/Trend-surfaces"
	fi

	if [ -z $RT_model ]; then
	    echo "WARNING: RT_model is not set in $OSARIS_PATH/config/${module_name}.config."
	    echo " Using defaul 10+r (bicubic with iterative fitting) ..."
	    RT_model="10+r"
	fi


	for grid_file in ${grid_files[@]}; do
	    echo "Detrending $grid_file ..."
	    if [ "$RT_safe_trend_files" -eq 1 ]; then
		trend_export="-T${RT_output_PATH}/Trend-surfaces/${grid-file::-4}-trend.grd"
	    else
		trend_export=""
	    fi

	    # Remove trends

	    gmt grdtrend "${RT_grid_input_PATH}/${grid_file}" -N$RT_model -D${RT_output_PATH}/${grid_file::-4}-detrend.grd $trend_export -V	    
	    

	done
    fi





    
    # Module actions end here
    ###########################



    # Stop runtime timer and print runtime
    module_end=`date +%s`    
    module_runtime=$((module_end-module_start))

    echo
    printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n\n' \
	$(($module_runtime/86400)) \
	$(($module_runtime%86400/3600)) \
	$(($module_runtime%3600/60)) \
	$(($module_runtime%60))
    echo
fi
