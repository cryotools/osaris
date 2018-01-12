

echo 
echo - - - - - - - - - - - - - - - - 
echo Processing coherence diffs
echo

mkdir -p $output_PATH/Coherence-diffs

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

# TODO: Calculate Damage Proxy Map
# for corr_diff_file in $( ls *.grd ); do gmt grdmath $corr_diff_file SQR SQRT = DPM_$corr_diff_file.grd; done


$OSARIS_PATH/lib/check-queue.sh $slurm_jobname 1

# $OSARIS_PATH/lib/coherence_differences.sh $output_PATH/Pairs-forward "corr_ll.grd" 2>&1 >>$logfile

