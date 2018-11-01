#!/usr/bin/env bash

######################################################################
#
# OSARIS module to calculate LOS displacement from unwrapped interferograms
#
# Input:
# - Path to directory containing the unwrapped interferograms
#
# David Loibl, 2018
#
#####################################################################

module_name="displacement"

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
    module_start=`date +%s`

    # Include the config file
    source ${module_config_PATH}/${module_name}.config



    ############################
    # Module actions start here
    
    echo "Starting the Dislpacement module ..."
    
    if [ -z "$unwrapped_intf_PATH" ]; then
	echo "No path to unwrapped interferograms specified in ${module_name}.config"
	echo "Trying default path $output_PATH/Pairs-forward/Interferograms-unwrapped ..."
	unwrapped_intf_PATH="$output_PATH/Pairs-forward/Interferograms-unwrapped"
    fi

    if [ ! -d "$unwrapped_intf_PATH" ]; then
	echo; echo "ERROR: Directory $unwrapped_intf_PATH does not exist. Exiting ..."
    else

	displ_output_PATH="$output_PATH/Displacement"
	mkdir -p $displ_output_PATH
	
	# TODO: read from .PRM files in Processing/raw
	radar_wavelength="0.554658"

	cd $unwrapped_intf_PATH

	unwrapped_intf_files=($( ls *.grd ))
	for unwrapped_intf_file in ${unwrapped_intf_files[@]}; do

	    # gmt grdmath ${unwrapped_intf_PATH}/${unwrapped_intf_file} $radar_wavelength MUL -79.58 MUL = $displ_output_PATH/${unwrapped_intf_file::-4}-losdispl.grd -V
	    
	    gmt grdmath ${unwrapped_intf_PATH}/${unwrapped_intf_file} $radar_wavelength MUL 4 DIV PI DIV -100 MUL = $displ_output_PATH/${unwrapped_intf_file::-4}-losdispl.grd -V

	    gmt grdedit -D//"mm"/1///"$PWD:t LOS displacement"/"equals negative range" $displ_output_PATH/${unwrapped_intf_file::-4}-losdispl.grd

	done	    

    fi    



    # Module actions end here
    ###########################



    # Stop runtime timer and print runtime
    displ_end=`date +%s`    
    displ_runtime=$((displ_end-displ_start))

    echo
    printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n\n' \
	$(($displ_runtime/86400)) \
	$(($displ_runtime%86400/3600)) \
	$(($displ_runtime%3600/60)) \
	$(($displ_runtime%60))
    echo
fi
