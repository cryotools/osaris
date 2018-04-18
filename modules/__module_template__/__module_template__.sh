#!/bin/bash

######################################################################
#
# Template for new OSARIS modules.
#
# Put module description here. If applicable, include infos on input 
# and output data.
#
# Make sure that this file, the module directory, the related 
# config file all have the same basename. In the first line below,
# replace __module_template__ with this name. 
# Do not use any special characters in your module name.
#
# You may use the following PATH variables:
# $OSARIS_PATH     -> OSARIS' program directory
# $work_PATH       -> Processing directory of a run
# $output_PATH     -> Output dircetory of a run
# $log_PATH        -> Log file directory of a run
# $topo_PATH       -> Directory with dem.grd used by GMTSAR
# $oribts_PATH     -> Directory containing the oribt files
#
#
# Author, year
#
#####################################################################

module_name="__module_template__"

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
    
    echo "Hello, I am the OSARIS module ${module_name}."
    echo; echo "Variable example_var is set to $example_var ..."

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
