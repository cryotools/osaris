#!/bin/bash


#################################################################
#
# Preparation of SAR data sets.
# 
# Usage: coh_differencing.sh input_path filename
# The 'input_path' should be referring to the 'Output' directory 
# of GSP containing the 'Interferograms' folder. Filename will
# be 'corr_ll.grd'.
#
################################################################


if [ $# -eq 0 ]; then
    echo
    echo "Usage: coh_differencing.sh input_path filename"  
    echo
elif [ $# -eq 1 ]; then
    echo
    echo "No filename provided. Assuming \"corr_ll.grd\""
    echo
else

    work_PATH="/data/scratch/loibldav/GSP/Golubin/Output"
    corr_filename="corr_ll.grd"
    counter=0

    cd $work_PATH/Interferograms
    mkdir -pv ../Temp
    mkdir -pv ../Corr_Diff

    folders=($( ls -r ))
    #echo ${folders[@]}

    for folder in "${folders[@]}"; do
	echo "Now working on folder: $folder"
	if [ ! -z ${folder_1} ]; then
	    folder_2=$folder_1
	    folder_1=$folder

	    corr_file_1_extent=$( gmt grdinfo -I- $work_PATH/Interferograms/$folder_1/$corr_filename ); corr_file_1_extent=${corr_file_1_extent:2}
	    corr_file_2_extent=$( gmt grdinfo -I- $work_PATH/Interferograms/$folder_2/$corr_filename ); corr_file_2_extent=${corr_file_2_extent:2}

	    echo $corr_file_1_extent
	    echo $corr_file_2_extent
	    corr_file_1_coord_string=$( echo $corr_file_1_extent | tr "/" "\n")
	    corr_file_2_coord_string=$( echo $corr_file_2_extent | tr "/" "\n")

	    # Create arrays of coordinates for each dataset
	    counter=0
	    for coord in $corr_file_1_coord_string; do
		corr_file_1_coord_array[$counter]=$coord
		counter=$((counter+1))
	    done

	    counter=0
	    for coord in $corr_file_2_coord_string; do
		corr_file_2_coord_array[$counter]=$coord
		counter=$((counter+1))
	    done

	    # Determine overal max and min values for both datasets


	    echo ${corr_file_1_coord_array[1]} 
	    echo ${corr_file_2_coord_array[1]}

	    remainder=$( expr $counter % 2 )

	    echo 
	    echo 
	    echo

	    counter=0
	    while [ $counter -lt 4 ]; do    
		if [ $counter -eq 0 ]; then
		    echo "Determining xmin"	
		    if [ $( bc <<< "${corr_file_1_coord_array[$counter]} > ${corr_file_2_coord_array[$counter]}" ) -eq 0 ]; then
			echo "file 1 has smaller xmin value"		   
			echo "Adding ${corr_file_1_coord_array[$counter]}"
			echo
			xmin=${corr_file_2_coord_array[$counter]}
		    else
			echo "file 2 has smaller xmin value"
			echo "Adding ${corr_file_2_coord_array[$counter]}"
			echo
			xmin=${corr_file_1_coord_array[$counter]}
		    fi
		elif [ $counter -eq 1 ]; then
		    echo "Determining xmax"	
		    if [ $( bc <<< "${corr_file_1_coord_array[$counter]} < ${corr_file_2_coord_array[$counter]}" ) -eq 0 ]; then
			echo "file 1 has higher xmax value"		   
			echo "Adding corr_file_2: ${corr_file_1_coord_array[$counter]}"
			echo
			xmax=${corr_file_2_coord_array[$counter]}
		    else
			echo "file 2 has higher xmax value"
			echo "Adding corr_file_1: ${corr_file_2_coord_array[$counter]}"
			echo
			xmax=${corr_file_1_coord_array[$counter]}
		    fi
		elif [ $counter -eq 2 ]; then
		    echo "Determining ymin"	
		    if [ $( bc <<< "${corr_file_1_coord_array[$counter]} > ${corr_file_2_coord_array[$counter]}" ) -eq 0 ]; then
			echo "file 1 has smaller ymin value"		   
			echo "Adding corr_file_2: ${corr_file_1_coord_array[$counter]}"
			echo
			ymin=${corr_file_2_coord_array[$counter]}
		    else
			echo "file 2 has smaller ymin value"
			echo "Adding corr_file_1: ${corr_file_2_coord_array[$counter]}"
			echo
			ymin=${corr_file_1_coord_array[$counter]}
		    fi
		elif [ $counter -eq 3 ]; then
		    echo "Determining ymax"	
		    if [ $( bc <<< "${corr_file_1_coord_array[$counter]} < ${corr_file_2_coord_array[$counter]}" ) -eq 0 ]; then
			echo "file 1 has max value"		   
			echo "Adding corr_file_2: ${corr_file_1_coord_array[$counter]}"
			echo
			ymax=${corr_file_2_coord_array[$counter]}
		    else
			echo "file 2 has max value"		   
			echo "Adding corr_file_1: ${corr_file_2_coord_array[$counter]}"
			echo
			ymax=${corr_file_1_coord_array[$counter]}
		    fi
		fi

		counter=$((counter+1))
	    done

	    echo "xmin: $xmin"
	    echo "xmax: $xmax"
	    echo "ymin: $ymin"
	    echo "ymax: $ymax"


	    cut_filename_1=$( echo corr-${folder_1:3:8}-${folder_1:27:8}-cut.grd )
	    cut_filename_2=$( echo corr-${folder_2:3:8}-${folder_2:27:8}-cut.grd )
	    corr_diff_filename=$( echo corr_diff--${folder_2:3:8}-${folder_2:27:8}---${folder_1:3:8}-${folder_1:27:8} )

	    echo
	    echo $cut_filename_1
	    echo $cut_filename_2
	    echo

	    #cut_filename_1=$( echo "$corr_file_1_basename-cut.grd" )
	    #cut_filename_2=$( echo "$corr_file_2_basename-cut.grd" )

	    cd $work_PATH/Interferograms       

	    cd $folder_1
	    gmt grdcut $corr_filename -G../../Temp/$cut_filename_1  -R$xmin/$xmax/$ymin/$ymax -V

	    cd ../$folder_2
	    gmt grdcut $corr_filename -G../../Temp/$cut_filename_2  -R$xmin/$xmax/$ymin/$ymax -V
	    #gmt grdcut ./$corr_file_2 -G$cut_filename_2 -R$xmin/$xmax/$ymin/$ymax 

	    cd ../../Temp
	    gmt grdmath $cut_filename_2 $cut_filename_1 SUB = $work_PATH/Corr_Diff/$corr_diff_filename.grd -V

	    cd $work_PATH/Corr_Diff
	    DX=$( gmt grdinfo $corr_diff_filename.grd -C | cut -f8 )
	    DPI=$( gmt gmtmath -Q $DX INV RINT = )   
	    gmt grdimage $corr_diff_filename.grd -C$work_PATH/Interferograms/$folder/corr.cpt -Jx1id -P -Y2i -X2i -Q -V > $work_PATH/Corr_Diff/$corr_diff_filename.ps
	    gmt psconvert $corr_diff_filename.ps -W+k+t"$corr_diff_filename" -E$DPI -TG -P -S -V -F$work_PATH/Corr_Diff/$corr_diff_filename.png
	    rm -f $corr_diff_filename.ps grad.grd ps2raster* psconvert*



	else
	    folder_1=$folder
	fi
    done
fi
