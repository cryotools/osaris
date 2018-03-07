#!/bin/bash

######################################################################
#
# Helper tool to obtain useful boundary and step values for CPT creation.
#
# Input: Min and max values, center at zero (optional)
# Output: string "lower_boundary/upper_boundary/step"
#
# David Loibl, 2018
#
#####################################################################

if [ $# -lt 2 ]; then
    echo
    echo "Usage: steps_boundaries.sh min_value max_value [center_zero]"  
    echo
else
    min=$1
    max=$2
    center_zero=$3

    diff=$( echo "$max - $min" | bc )
    if [ $( echo "$diff > 5000" | bc ) -eq 1 ]; then
	step=500
    elif [ $( echo "$diff > 2000" | bc ) -eq 1 ]; then
	step=200
    elif [ $( echo "$diff > 1000" | bc ) -eq 1 ]; then
	step=100
    elif [ $( echo "$diff > 500" | bc ) -eq 1 ]; then
	step=50
    elif [ $( echo "$diff > 200" | bc ) -eq 1 ]; then
	step=20
    elif [ $( echo "$diff > 100" | bc ) -eq 1 ]; then
	step=10
    elif [ $( echo "$diff > 50" | bc ) -eq 1 ]; then
	step=5
    elif [ $( echo "$diff > 20" | bc ) -eq 1 ]; then
	step=2
    elif [ $( echo "$diff > 10" | bc ) -eq 1 ]; then
	step=1
    elif [ $( echo "$diff > 5" | bc ) -eq 1 ]; then
	step="0.5"
    elif [ $( echo "$diff > 2" | bc ) -eq 1 ]; then
	step="0.2"
    elif [ $( echo "$diff > 1" | bc ) -eq 1 ]; then
	step="0.1"
    elif [ $( echo "$diff > 0.5" | bc ) -eq 1 ]; then
	step="0.05"
    elif [ $( echo "$diff > 0.2" | bc ) -eq 1 ]; then
	step="0.02"
    else
	step="0.01"
    fi
    min_remainder=$( echo "${min} % $step" | bc )
    lower_boundary=$( echo "${min} - $min_remainder" | bc )
    max_remainder=$( echo "${max} % $step" | bc )
    upper_boundary=$( echo "${max} - ${max_remainder} + $step" | bc )
    
    if [ "$center_zero" -eq 1 ]; then
	if [ $( echo "$lower_boundary < 0" | bc ) -eq 1 ] && [ $( echo "$upper_boundary > 0" | bc ) -eq 1 ]; then
	    lower_boundary_pos=$( echo "$lower_boundary * -1" | bc )
	    if [ $( echo "$lower_boundary_pos < $upper_boundary" | bc ) -eq 1 ]; then
		lower_boundary=$( echo "$upper_boundary * -1" | bc )
	    else
		upper_boundary=$( echo "$lower_boundary * -1" | bc )
	    fi
	fi
    fi

    # Remove tailing zeros
    # lower_boundary="${lower_boundary/%$( echo $lower_boundary | grep -oP 0*$ )}"
    # upper_boundary="${upper_boundary/%$( echo $upper_boundary | grep -oP 0*$ )}"
    echo "$lower_boundary/$upper_boundary/$step"
fi
