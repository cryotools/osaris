#!/bin/bash

######################################################################
#
# OSARIS module to homgenize unwrapped intfs and LoS displacement
#
# Shift all unwrapped intereferograms and LoS displacement file by 
# their offset to a 'stable ground point' as identified by the
# simplePSI module. 
#
# Input: 
#    - unwrap_mask_ll.grd files from 'Pairs forward' output folder
#    - los_ll.grd files from 'Pairs forward' output folder
#    - ps_coords.xy from 'PSI' output folder
#
# Output:
#    - homogenized unwrapped interferograms (grd)
#    - homogenized LoS displacements (grd) 
#
#
# David Loibl, 2018
#
#####################################################################

HI_start=`date +%s`


echo; echo "Homogenizing interferograms ..."
HI_output_PATH="$output_PATH/Homogenized-Intfs"
mkdir -p $HI_output_PATH

for swath in ${swaths_to_process[@]}; do

    if [ -f $output_PATH/PSI/ps_coords-F$swath.xy ]; then
	sg_lat=($( cat $output_PATH/PSI/ps_coords-F$swath.xy | awk '{ print $1 }' ))
	sg_lon=($( cat $output_PATH/PSI/ps_coords-F$swath.xy | awk '{ print $2 }' ))

	if [ -n $ps_lat ] && [ -n $ps_lon ]; then	
	    cd $output_PATH/Pairs-forward
	    
	    folders=($( ls -d *F$swath/ ))

	    for folder in "${folders[@]}"; do
		folder=${folder::-1}
		echo; echo "Processing data from $folder"
		if [ -f "$folder/unwrap_mask_ll.grd" ]; then
		    # Get xy coordinates of 'stable ground point' from file and check the value the raster set has at this location.
		    gmt grdtrack $output_PATH/PSI/ps_coords-F$swath.xy -G$folder/unwrap_mask_ll.grd >> $HI_output_PATH/sg_vals.xyz
		    sg_unwrap_trk=$( gmt grdtrack $output_PATH/PSI/ps_coords-F$swath.xy -G$folder/unwrap_mask_ll.grd )
		    if [ ! -z ${sg_unwrap_trk+x} ]; then
			sg_unwrap_val=$( echo "$sg_unwrap_trk" | awk '{ print $3 }')
			#sg_unwrap_diff=$(echo "scale=10; 0-$sg_unwrap_val" | bc -l)

			if [ $debug -gt 1 ]; then echo "stable ground diff unwrap: $sg_unwrap_val"; fi
		    else
			echo "GMT grdtrack for stable ground yielded no result. Skipping"
		    fi
		    
		    if [ ! -z ${sg_unwrap_val+x} ]; then
			# Shift input grid (unwrapped intf) so that the 'stable ground value' is zero
			gmt grdmath $folder/unwrap_mask_ll.grd $sg_unwrap_val SUB = $HI_output_PATH/${folder}-hintf.grd -V
		    else 
			echo "Unwrap difference calculation for stable ground point failed in ${folder}. Skipping ..."
		    fi		    
		else 
		    echo "No unwrapped interferogram found in ${folder}. Skipping ..."
		fi


		if [ -f "$folder/los_ll.grd" ]; then
		    # Get xy coordinates of 'stable ground point' from file and check the value the raster set has at this location. 
		    sg_losdsp_trk=$( gmt grdtrack $output_PATH/PSI/ps_coords-F$swath.xy -G$folder/los_ll.grd )
		    if [ ! -z ${sg_losdsp_trk+x} ]; then
			sg_losdsp_val=$( echo "$sg_losdsp_trk" | awk '{ print $3 }')
			if [ $debug -gt 1 ]; then echo "stable ground diff losdsp: $sg_losdsp_val"; fi
		    else
			echo "GMT grdtrack for LOS stable ground yielded no result. Skipping"
		    fi	    

		    if [ ! -z ${sg_losdsp_val+x} ]; then
			# Shift input grid (los displacement) so that the 'stable ground value' is zero
			gmt grdmath $folder/los_ll.grd $sg_losdsp_val SUB = $HI_output_PATH/${folder}-hlosdsp.grd -V
		    else 
			echo "LOS difference calculation for stable ground point failed in ${folder}. Skipping ..."
		    fi
		else 
		    echo "No LOS file found in ${folder}. Skipping ..."
		fi

	    done
	else
	    echo "Module ERROR: Persistent scatterer coordinates are not set. Exiting interferogram homogenization."
	fi

    else 
	echo "Module ERROR: Required file ps_coords-F$swath.xy not found. Please check conifg of 'simple_PSI' module. Exiting interferogram homogenization."
    fi
done

HI_end=`date +%s`

HI_runtime=$((HI_end-HI_start))

printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n' $(($HI_runtime/86400)) $(($HI_runtime%86400/3600)) $(($HI_runtime%3600/60)) $(($HI_runtime%60))
echo


