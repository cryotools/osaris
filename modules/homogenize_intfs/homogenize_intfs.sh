#!/bin/bash

######################################################################
#
# OSARIS module to homgenize unwrapped intfs
#
# Input table provides coordinates of 'stable ground point' which will
# be set to zero in all intfs. The rest of each unwrapped intf will be
# shifted according to the offset of the 'stable ground point' to zero.
#
#
# David Loibl, 2018
#
#####################################################################

start=`date +%s`


# if [ ! -f "$OSARIS_PATH/config/homogenize_intfs.sh" ]; then
#     echo
#     echo "$OSARIS_PATH/config/homogenize_intfs.config is not a valid configuration file"  
#     echo
#     exit 2
# else
# source $OSARIS_PATH/config/homogenize_intfs.config

echo; echo "Homogenizing interferograms ..."
mkdir -p $output_PATH/homogenized_intfs

if [ -f $output_PATH/PSI/ps_coords.xy ]; then
    sg_lat=($( cat $output_PATH/PSI/ps_coords.xy | awk '{ print $1 }' ))
    sg_lon=($( cat $output_PATH/PSI/ps_coords.xy | awk '{ print $2 }' ))
    if [ -n $ps_lat ] && [ -n $ps_lon ]; then
	for swath in ${swaths_to_process[@]}; do
	    cd $output_PATH/Pairs-forward/F$swath
	    
	    folders=($( ls -d */ ))

	    for folder in "${folders[@]}"; do
		folder=${folder::-1}
		echo; echo "Processing data from $folder"
		if [ -f "$folder/unwrap_mask_ll.grd" ]; then
		    # Get xy coordinates of 'stable ground point' from file and check the value the raster set has at this location.
		    gmt grdtrack $output_PATH/PSI/ps_coords.xy -G$folder/unwrap_mask_ll.grd >> $output_PATH/homogenized_intfs/sg_vals.xyz
		    sg_unwrap_trk=$( gmt grdtrack $output_PATH/PSI/ps_coords.xy -G$folder/unwrap_mask_ll.grd )
		    if [ ! -z ${sg_unwrap_trk+x} ]; then
			sg_unwrap_val=$( echo "$sg_unwrap_trk" | awk '{ print $3 }')
			#sg_unwrap_diff=$(echo "scale=10; 0-$sg_unwrap_val" | bc -l)

			echo "stable ground diff unwrap: $sg_unwrap_val"
		    else
			echo "GMT grdtrack for stable ground yielded no result. Skipping"
		    fi

		    
		    if [ ! -z ${sg_unwrap_val+x} ]; then
			# Shift input grid (unwrapped intf) so that the 'stable ground value' is zero
			gmt grdmath $folder/unwrap_mask_ll.grd $sg_unwrap_val SUB = $output_PATH/homogenized_intfs/hintf_${folder}.grd -V
		    else 
			echo "Unwrap difference calculation for stable ground point failed in ${folder}. Skipping ..."
		    fi		    
		else 
		    echo "No unwrapped interferogram found in ${folder}. Skipping ..."
		fi


		if [ -f "$folder/los_ll.grd" ]; then
		    # Get xy coordinates of 'stable ground point' from file and check the value the raster set has at this location 
		    echo "Getting track"
		    sg_losdsp_trk=$( gmt grdtrack $output_PATH/PSI/ps_coords.xy -G$folder/los_ll.grd )
		    if [ ! -z ${sg_losdsp_trk+x} ]; then
			echo "Getting sg val"
			sg_losdsp_val=$( echo "$sg_losdsp_trk" | awk '{ print $3 }')
			echo "Calculating  difference"
			#sg_losdsp_diff=$( echo "scale=10; 0-$sg_losdsp_val" | bc -l )

			echo "stable ground diff losdsp: $sg_losdsp_val"
		    else
			echo "GMT grdtrack for LOS stable ground yielded no result. Skipping"
		    fi
	    

		    if [ ! -z ${sg_losdsp_val+x} ]; then
			# Shift input grid (los displacement) so that the 'stable ground value' is zero
			gmt grdmath $folder/los_ll.grd $sg_losdsp_val SUB = $output_PATH/homogenized_intfs/hlosdsp_${folder}.grd -V
		    else 
			echo "LOS difference calculation for stable ground point failed in ${folder}. Skipping ..."
		    fi
		else 
		    echo "No LOS file found in ${folder}. Skipping ..."
		fi

	    done
	done
    else
	echo "Module ERROR: Persistent scatterer coordinates are not set. Exiting interferogram homogenization."
    fi
else 
    echo "Module ERROR: Required file ps_coords.xy not found. Please check conifg of 'simple_PSI' module. Exiting interferogram homogenization."
fi

# echo; echo
# echo "Cleaning up"
# rm -r temp
# rm merged_dem.grd
# echo; echo

end=`date +%s`

runtime=$((end-start))

printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n' $(($runtime/86400)) $(($runtime%86400/3600)) $(($runtime%3600/60)) $(($runtime%60))
echo


