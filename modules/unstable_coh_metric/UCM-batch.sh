#!/bin/bash


function cut2same_extent {
    file_1=$1
    file_2=$2
    
    #filename_1=$(basename $file_1 .grd)-1
    #filename_2=$(basename $file_2 .grd)-2
    
    result_PATH=$3
    mkdir -p $result_PATH
    
    #supercode=$(date +%s)-$(( RANDOM % 10000 ))
    #tempdir_PATH=$result_PATH/Temp-$supercode   
    # mkdir -p $tempdir_PATH

    file_1_extent=$( gmt grdinfo -I- $file_1 ); file_1_extent=${file_1_extent:2}
    file_2_extent=$( gmt grdinfo -I- $file_2 ); file_2_extent=${file_2_extent:2}

    #echo $file_1_extent
    #echo $file_2_extent

    file_1_coord_string=$( echo $file_1_extent | tr "/" "\n")
    file_2_coord_string=$( echo $file_2_extent | tr "/" "\n")

    # Create arrays of coordinates for each dataset
    counter=0
    for coord in $file_1_coord_string; do
	file_1_coord_array[$counter]=$coord
	counter=$((counter+1))
    done

    counter=0
    for coord in $file_2_coord_string; do
	file_2_coord_array[$counter]=$coord
	counter=$((counter+1))
    done

    # Determine overal max and min values for both datasets
    # echo ${file_1_coord_array[1]}
    # echo ${file_2_coord_array[1]}

    # remainder=$( expr $counter % 2 )

    counter=0
    while [ $counter -lt 4 ]; do
	if [ $counter -eq 0 ]; then
	    if [ $( bc <<< "${file_1_coord_array[$counter]} > ${file_2_coord_array[$counter]}" ) -eq 0 ]; then 
		xmin=${file_2_coord_array[$counter]}
	    else
		xmin=${file_1_coord_array[$counter]}
	    fi
	elif [ $counter -eq 1 ]; then
	    if [ $( bc <<< "${file_1_coord_array[$counter]} < ${file_2_coord_array[$counter]}" ) -eq 0 ]; then
		xmax=${file_2_coord_array[$counter]}
	    else
		xmax=${file_1_coord_array[$counter]}
	    fi
	elif [ $counter -eq 2 ]; then
	    if [ $( bc <<< "${file_1_coord_array[$counter]} > ${file_2_coord_array[$counter]}" ) -eq 0 ]; then
		ymin=${file_2_coord_array[$counter]}
	    else
		ymin=${file_1_coord_array[$counter]}
	    fi
	elif [ $counter -eq 3 ]; then
	    if [ $( bc <<< "${file_1_coord_array[$counter]} < ${file_2_coord_array[$counter]}" ) -eq 0 ]; then
		ymax=${file_2_coord_array[$counter]}
	    else
		ymax=${file_1_coord_array[$counter]}
	    fi
	fi

	counter=$((counter+1))
    done
    
    gmt grdcut $file_1 -G$result_PATH/$file_1  -R$xmin/$xmax/$ymin/$ymax
    gmt grdcut $file_2 -G$result_PATH/$file_2  -R$xmin/$xmax/$ymin/$ymax

}


UCM_work_PATH=$1
UCM_output_PATH=$2
corr_file=$3
high_corr_file=$4
high_corr_threshold=$5
swath=$6

cd $UCM_work_PATH/input/F$swath/

echo "Extracting high coherence areas (threshold: $high_corr_threshold)"
gmt grdclip $high_corr_file -GHC_$high_corr_file -V -Sb$high_corr_threshold/NaN;

echo "Now working on:"; echo "Corr file: $corr_file"; echo "High corr file: HC_${corr_files[$( bc <<< $count-1 )]}"
echo "Cutting files to same extent ..."

cut2same_extent $corr_file HC_$high_corr_file $UCM_work_PATH/cut_files

echo; echo "Processing Unstable Coherence Metric ..."
cd $UCM_work_PATH/cut_files
UCM_file="UCM_${high_corr_file:10:8}-${high_corr_file:33:8}---${corr_file:7:8}-${corr_file:30:8}_F${swath}.grd"
echo "gmt grdmath $high_corr_file $corr_file SUB -V1 = $work_PATH/UCM/temp/$UCM_file"
gmt grdmath HC_$high_corr_file $corr_file SUB -V1 = $UCM_work_PATH/temp/$UCM_file

cd $UCM_work_PATH/temp
echo "gmt grdclip $UCM_file -G$output_PATH/UCM/$UCM_file -Sb0/NaN"
gmt grdclip $UCM_file -G$UCM_output_PATH/$UCM_file -Sb0/NaN
echo; echo
