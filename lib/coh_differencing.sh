#!/bin/bash

# -R73.5888888889/74.8444444444/41.0111111111/42.6444444444
#for intf_folder in $( ls -r); do 
    #find ./$intf_folder -name "*.png" -o -name "*.ps" | tar czvf $intf_folder.tar.gz -T -; 
#done
work_PATH="/data/scratch/loibldav/GSP/Golubin/Output/Interferograms"
corr_filename="corr_ll.grd"
counter=0

cd $work_PATH
mkdir -pv ../Temp
mkdir -pv ../Corr_Diff

folders=($( ls -r ))
#echo ${folders[@]}

for folder in "${folders[@]}"; do
    echo "Now working on folder: $folder"
    if [ ! -z ${folder_1} ]; then
       folder_2=$folder_1
       folder_1=$folder

       corr_file_1_extent=$( gmt grdinfo -I- $work_PATH/$folder_1/$corr_filename ); corr_file_1_extent=${corr_file_1_extent:2}
       corr_file_2_extent=$( gmt grdinfo -I- $work_PATH/$folder_2/$corr_filename ); corr_file_2_extent=${corr_file_2_extent:2}

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
       corr_diff_filename=$( echo corr_diff--${folder_2:3:8}-${folder_2:27:8}---${folder_1:3:8}-${folder_1:27:8}.grd )

       echo
       echo $cut_filename_1
       echo $cut_filename_2
       echo

       #cut_filename_1=$( echo "$corr_file_1_basename-cut.grd" )
       #cut_filename_2=$( echo "$corr_file_2_basename-cut.grd" )

       cd $work_PATH       

       cd $folder_1
       gmt grdcut $corr_filename -G../../Temp/$cut_filename_1  -R$xmin/$xmax/$ymin/$ymax -V

       cd ../$folder_2
       gmt grdcut $corr_filename -G../../Temp/$cut_filename_2  -R$xmin/$xmax/$ymin/$ymax -V
       #gmt grdcut ./$corr_file_2 -G$cut_filename_2 -R$xmin/$xmax/$ymin/$ymax 

       cd ../../Temp
       gmt grdmath $cut_filename_2 $cut_filename_1 SUB = ../Corr_Diff/$corr_diff_filename -V
    else
	folder_1=$folder
    fi
done
#    remainder=$( expr $counter % 2 )
#    echo "Remainder: $remainder"
#    if [ "$remainder" -eq 0 ]; then
#	    corr_file_extremes_array=(${corr_files_extremes_array[@]} ${corr_file_1_coord_array[$counter]})

#if ${corr_file_1_extent:3:} 

#gmt grdmath ./S1A20160616_010441_F3---S1A20160710_010442_F3/corr_ll.grd ./S1A20160523_010440_F3---S1A20160616_010441_F3/corr_ll.grd SUB = corr_diff_20160616-20160710--201600523-20160616.grd

#gmt grdinfo -I- corr_ll.grd

#S1_file[$counter]=${S1_package:0:${#S1_package}-4} 

