if [ "$process_reverse_intfs" -eq 1 ]; then
    cd $work_PATH/raw/
    scene_pair_reverse=${scene_2:15:8}--${scene_1:15:8}
    echo "Creating reverse directory $scene_pair_name"
    mkdir -pv $scene_pair_reverse-aligned
    cp -r --preserve=links $scene_pair_name-aligned/. $scene_pair_reverse-aligned/
    echo "cp -r --preserve=links $scene_pair_name-aligned/. $scene_pair_reverse-aligned/"

    slurm_jobname="$slurm_jobname_prefix-$mode-rev"

    sbatch \
	--ntasks=$slurm_ntasks \
	--output=$log_PATH/PP-$mode-%j-rev-out \
	--error=$log_PATH/PP-$mode-%j-rev-out \
	--workdir=$work_PATH \
	--job-name=$slurm_jobname \
	--qos=$slurm_qos \
	--account=$slurm_account \
	--partition=$slurm_partition \
	--mail-type=$slurm_mailtype \
	$OSARIS_PATH/lib/PP-pairs.sh \
	$scene_2 \
	$orbit_2 \
	$scene_1 \
	$orbit_1 \
	$swath \
	$config_file \
	$OSARIS_PATH/$gmtsar_config_file \
	$OSARIS_PATH \
	"reverse"
fi
