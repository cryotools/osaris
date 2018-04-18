#!/bin/bash

start=`date +%s`

echo; echo "Starting UCM processing ..."; echo

UCM_work_PATH=$1
UCM_output_PATH=$2
corr_file=$3
high_corr_file=$4
high_corr_threshold=$5
boundary_box=$6
swath=$7

cd $UCM_work_PATH/input

echo; echo "Grdinfo high corr file:"
gmt grdinfo $high_corr_file

echo "Extracting high coherence areas (threshold: $high_corr_threshold)"
gmt grdclip $high_corr_file -GHC_$high_corr_file -R$boundary_box -V -Sb$high_corr_threshold/NaN;

echo "Now working on:"; echo "Corr file: $corr_file"; echo "High corr file: $high_corr_file"
echo "Cutting files to same extent ..."

gmt grdcut $corr_file -G$UCM_work_PATH/cut_files/$corr_file -R$boundary_box -V
gmt grdcut HC_$high_corr_file -G$UCM_work_PATH/cut_files/HC_$high_corr_file -R$boundary_box -V
# cut2same_extent 


echo; echo "Processing Unstable Coherence Metric ..."
cd $UCM_work_PATH/cut_files
UCM_file="${high_corr_file:5:8}-${high_corr_file:15:8}---${corr_file:5:8}-${corr_file:15:8}_F${swath}-UCM.grd"
echo "gmt grdmath $high_corr_file $corr_file SUB -V1 = $work_PATH/UCM/temp/$UCM_file"
gmt grdmath HC_$high_corr_file $corr_file SUB -V1 = $UCM_work_PATH/temp/$UCM_file

cd $UCM_work_PATH/temp
echo "gmt grdclip $UCM_file -G$output_PATH/UCM/$UCM_file -Sb0/NaN"
gmt grdclip $UCM_file -G$UCM_output_PATH/$UCM_file -Sb0/NaN
echo; echo

if [ -f $UCM_output_PATH/$UCM_file ]; then status_UCM=1; else status_UCM=0; fi

end=`date +%s`
runtime=$((end-start))

echo "${high_corr_file:7:8}-${high_corr_file:30:8} ${corr_file:7:8}-${corr_file:30:8} $SLURM_JOB_ID $runtime $status_UCM" >> $output_PATH/Reports/PP-UCM-stats.tmp

printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n' $(($runtime/86400)) $(($runtime%86400/3600)) $(($runtime%3600/60)) $(($runtime%60))
