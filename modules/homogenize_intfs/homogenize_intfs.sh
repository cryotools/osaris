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
# David Loibl, 2017
#
#####################################################################

start=`date +%s`


if [ ! -f "$OSARIS_PATH/config/homogenize_intfs.sh" ]; then
    echo
    echo "$OSARIS_PATH/config/homogenize_intfs.config is not a valid configuration file"  
    echo
    exit 2
else
    source $OSARIS_PATH/config/homogenize_intfs.config

    echo; echo "Homogenizing interferograms"

    for swath in ${swaths_to_process[@]}; do
	cd $output_PATH/Pairs-forward/F$swath

	folders=($( ls -r ))

	for folder in "${folders[@]}"; do
	    echo "Adding coherence from $folder ..."
	    cd $output_PATH/Pairs-forward/F$swath
	    if [ ! -z ${folder_1} ]; then
		folder_2=$folder_1
		folder_1=$folder

		coherence_diff_filename=$( echo corr_diff--${folder_2:2:8}-${folder_2:25:8}-F$swath---${folder_1:2:8}-${folder_1:25:8}-F$swath )
		
		slurm_jobname="$slurm_jobname_prefix-CD"

		sbatch \
		    --ntasks=1 \
		    --output=$log_PATH/OSS-CoD-%j-out \
		    --error=$log_PATH/OSS-CoD-%j-out \
		    --workdir=$work_PATH \
		    --job-name=$slurm_jobname \
		    --qos=$slurm_qos \
		    --account=$slurm_account \
		    --mail-type=$slurm_mailtype \
		    $OSARIS_PATH/lib/difference.sh \
		    $output_PATH/Pairs-forward/F$swath/$folder_1/corr_ll.grd \
		    $output_PATH/Pairs-forward/F$swath/$folder_2/corr_ll.grd \
		    $output_PATH/Coherence-diffs \
		    $coherence_diff_filename \
		    $OSARIS_PATH/lib/palettes/corr_diff_brown_green.cpt 2>&1 >>$logfile
		# TODO: Create an adequate palette for coherence differences		
		
	    else
		folder_1=$folder
	    fi
	done
    done

$OSARIS_PATH/lib/check-queue.sh $slurm_jobname 1
    
    # Get xy coordinates of 'stable ground point' from file and check the value the raster set has at this location.
    stable_ground_val=$(gmt grdtrack track_4.xyg -Ghawaii_topo.nc)

    stable_ground_diff=$(echo "scale=10; 0-$stable_ground_val" | bc -l)

    # Shift input grid (unwrapped intf) so that the 'stable ground value' is zero
    gmt grdmath $input_grid $stable_ground_diff SUB = $output_grid

    echo; echo
    echo "Cleaning up"
    rm -r temp
    rm merged_dem.grd
    echo; echo

    end=`date +%s`

    runtime=$((end-start))

    printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n' $(($runtime/86400)) $(($runtime%86400/3600)) $(($runtime%3600/60)) $(($runtime%60))
    echo



fi


