#!/usr/bin/env bash

######################################################################
#
# Send minimal jobs to Slurm queue to wake up sleeping nodes
#
# Requires a file 'ping.config' in the OSARIS config folder containing
# the Slurm configuration. Get startet by copying the config_template 
# file from the templates folder and fit it to your setup.
#
# David Loibl, 2017
#
#####################################################################

module_name="ping"


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

    # Include the config file
    source ${module_config_PATH}/${module_name}.config

    i=0
    while [ $i -lt $ping_count ]; do
	sbatch \
	    --output=/dev/null \
	    --error=/dev/null \
	    --workdir=$input_PATH \
	    --job-name=ping \
	    --qos=$slurm_qos \
	    --account=$slurm_account \
	    --partition=$slurm_partition \
	    --mail-type=NONE \
	    $OSARIS_PATH/modules/ping/ping_batch.sh
	((i++))
    done
fi
