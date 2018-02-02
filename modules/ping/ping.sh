#!/bin/bash

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

if [ ! -f "$OSARIS_PATH/config/ping.config" ]; then
    echo
    echo "Cannot open ping.config in the OSARIS config folder. Please provide a valid config file."
    echo
else
    # Ping it on!
    source $OSARIS_PATH/config/ping.config
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
