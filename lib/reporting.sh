#!/usr/bin/env bash

#################################################################
#
# Preparation OSARIS run reports.
# 
################################################################


# Create input file list
cd $input_PATH
for inputfile in $( ls -1 ); do 
    echo $inputfile >> $output_PATH/Reports/input_files.list
    echo ${inputfile:17:8} >> $output_PATH/Reports/input_dates.tmp    
done
input_file_count=$( ls -l | grep -v ^d | wc -l )
echo "Total input file count: $input_file_count" >> $output_PATH/Reports/input_files.list

sort $output_PATH/Reports/input_dates.tmp | uniq > $output_PATH/Reports/input_dates.list
rm $output_PATH/Reports/input_dates.tmp


# Create report for file extraction
if [ $PS_extract -eq 1 ]; then	
    sort $output_PATH/Reports/PP-extract-stats.tmp > $output_PATH/Reports/PP-extract-stats.list

    printf "\n OSARIS file extract report \n" > $output_PATH/Reports/PP-extract.report
    printf "Total number of files extracted: $(cat $output_PATH/Reports/PP-extract-stats.list | wc -l) \n \n" >> $output_PATH/Reports/PP-extract.report

    while read -r PP_job; do
	printf "Slurm job ID: $(echo $PP_job | awk '{ print $3}') \n" >> $output_PATH/Reports/PP-extract.report
	printf "  File name: $(echo $PP_job | awk '{ print $1}') \n" >> $output_PATH/Reports/PP-extract.report
	PP_extract_runtime=$(echo $PP_job | awk '{ print $2}')
	printf '  Processing time:\t %02dd %02dh:%02dm:%02ds\n' $(($PP_extract_runtime/86400)) $(($PP_extract_runtime%86400/3600)) $(($PP_extract_runtime%3600/60)) $(($PP_extract_runtime%60)) >> $output_PATH/Reports/PP-extract.report
	PP_extract_total_runtime=$((PP_extract_total_runtime + PP_extract_runtime))
	printf "\n \n"  >> $output_PATH/Reports/PP-extract.report
    done < "$output_PATH/Reports/PP-extract-stats.list"
    
    printf 'Total processing time:\t %02dd %02dh:%02dm:%02ds\n' $(($PP_extract_total_runtime/86400)) $(($PP_extract_total_runtime%86400/3600)) $(($PP_extract_total_runtime%3600/60)) $(($PP_extract_total_runtime%60)) >> $output_PATH/Reports/PP-extract.report

    printf "File extraction processing time [s]: \t $PP_extract_total_runtime \n" >> $output_PATH/Reports/processing-time.report
    printf 'File extraction proc. time formatted:\t %02dd %02dh:%02dm:%02ds\n' $(($PP_extract_total_runtime/86400)) $(($PP_extract_total_runtime%86400/3600)) $(($PP_extract_total_runtime%3600/60)) $(($PP_extract_total_runtime%60)) >> $output_PATH/Reports/processing-time.report
    if [ $clean_up -ge 1 ]; then
	rm $output_PATH/Reports/PP-extract-stats.list $output_PATH/Reports/PP-extract-stats.tmp
    fi
fi


# Create report for PP pairs
sort $output_PATH/Reports/PP-pairs-stats.tmp > $output_PATH/Reports/PP-pairs-stats.list

printf "\n OSARIS interferometric pair processing report \n" > $output_PATH/Reports/PP-pairs.report
printf "Total number of pair jobs executed: $(cat $output_PATH/Reports/PP-pairs-stats.list | wc -l) \n \n" >> $output_PATH/Reports/PP-pairs.report

while read -r PP_job; do
    printf "Slurm job ID:\t\t\t $(echo $PP_job | awk '{ print $3}') \n" >> $output_PATH/Reports/PP-pairs.report
    scene_1_date=$(echo $PP_job | awk '{ print $1 }')
    scene_2_date=$(echo $PP_job | awk '{ print $2 }')
    printf "Scene dates:\t\t\t $scene_1_date $scene_2_date \n" >> $output_PATH/Reports/PP-pairs.report
    take_diff=$(( ($(date --date="$scene_2_date" +%s) - $(date --date="$scene_1_date" +%s) )/(60*60*24) ))
    printf "  Days between data takes:\t $take_diff \n" >> $output_PATH/Reports/PP-pairs.report

    if [ ! "$(echo $PP_job | awk '{ print $5 }')" -eq 1 ]; then
	printf "  Status Amplitude:\t\t failed \n" >> $output_PATH/Reports/PP-pairs.report
    else
	printf "  Status Amplitude:\t\t ok \n" >> $output_PATH/Reports/PP-pairs.report
    fi

    if [ ! "$(echo $PP_job | awk '{ print $6 }')" -eq 1 ]; then
	printf "  Status Coherence:\t\t failed \n" >> $output_PATH/Reports/PP-pairs.report
    else
	printf "  Status Coherence:\t\t ok \n" >> $output_PATH/Reports/PP-pairs.report
    fi

    if [ ! "$(echo $PP_job | awk '{ print $7 }')" -eq 1 ]; then
	printf "  Status Phase:\t\t\t failed \n" >> $output_PATH/Reports/PP-pairs.report
    else
	printf "  Status Phase:\t\t\t ok \n" >> $output_PATH/Reports/PP-pairs.report
    fi

    if [ "$(echo $PP_job | awk '{ print $8 }')" -eq 1 ]; then
	printf "  Status Unwrapped Intf.:\t ok \n" >> $output_PATH/Reports/PP-pairs.report
    elif [ "$(echo $PP_job | awk '{ print $8 }')" -eq 2 ]; then
	printf "  Status Unwrapped Intf.:\t not processed \n" >> $output_PATH/Reports/PP-pairs.report
    else
	printf "  Status Unwrapped Intf.:\t failed \n" >> $output_PATH/Reports/PP-pairs.report
    fi

    if [ "$(echo $PP_job | awk '{ print $9 }')" -eq 1 ]; then
	printf "  Status LoS Displace.:\t\t ok \n" >> $output_PATH/Reports/PP-pairs.report
    elif [ "$(echo $PP_job | awk '{ print $9 }')" -eq 2 ]; then
	printf "  Status LoS Displace.:\t\t not processed \n" >> $output_PATH/Reports/PP-pairs.report
    else
	printf "  Status LoS Displace.:\t\t failed \n" >> $output_PATH/Reports/PP-pairs.report
    fi
    
    PP_runtime=$(echo $PP_job | awk '{ print $4}')
    printf '  Processing time:\t\t %02dd %02dh:%02dm:%02ds\n' $(($PP_runtime/86400)) $(($PP_runtime%86400/3600)) $(($PP_runtime%3600/60)) $(($PP_runtime%60)) >> $output_PATH/Reports/PP-pairs.report     

    PP_total_runtime=$((PP_total_runtime + PP_runtime))
    printf "\n \n" >> $output_PATH/Reports/PP-pairs.report
done < "$output_PATH/Reports/PP-pairs-stats.list"

printf 'Total processing time:\t %02dd %02dh:%02dm:%02ds\n' $(($PP_total_runtime/86400)) $(($PP_total_runtime%86400/3600)) $(($PP_total_runtime%3600/60)) $(($PP_total_runtime%60)) >> $output_PATH/Reports/PP-pairs.report

printf 'PP InSAR processing time:\t %02dd %02dh:%02dm:%02ds\n' $(($PP_total_runtime/86400)) $(($PP_total_runtime%86400/3600)) $(($PP_total_runtime%3600/60)) $(($PP_total_runtime%60)) >> $output_PATH/Reports/processing-time.report

if [ $clean_up -ge 1 ]; then
    rm $output_PATH/Reports/PP-pairs-stats.list $output_PATH/Reports/PP-pairs-stats.tmp
fi


# Create overview report
printf "\n OSARIS Report \n \n" > $output_PATH/Reports/$report_filename
printf "Processing started at $(date -d @$OSARIS_start_time) \n"  >> $output_PATH/Reports/$report_filename
printf "Number of input files: $input_file_count \n" >> $output_PATH/Reports/$report_filename
printf 'Total processing time (estimate):\t %02dd %02dh:%02dm:%02ds\n' $(($total_runtime/86400)) $(($total_runtime%86400/3600)) $(($total_runtime%3600/60)) $(($total_runtime%60)) >> $output_PATH/Reports/$report_filename
printf 'Elapsed wall clock time:\t\t\t %02dd %02dh:%02dm:%02ds\n' $(($OSARIS_runtime/86400)) $(($OSARIS_runtime%86400/3600)) $(($OSARIS_runtime%3600/60)) $(($OSARIS_runtime%60)) >> $output_PATH/Reports/$report_filename
