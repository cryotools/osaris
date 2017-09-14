#!/bin/bash


#################################################################
#
# Calculate difference between two GRD datasets.
# 
# Usage: difference.sh file1 file2 output_directory
# 
# Both input files must be in GRD format.
# 
################################################################


if [ $# -lt 3 ]; then
    echo
    echo "Usage: difference.sh file1 file2 output_directory"  
    echo
else
    
    file_1=$1
    file_2=$2
    filename_1=$(basename $file_1 .grd)
    filename_2=$(basename $file_2 .grd)
    output_PATH=$3

    mkdir -pv $output_PATH
    mkdir -pv $output_PATH/Temp

   file_1_extent=$( gmt grdinfo -I- $file_1 ); file_1_extent=${file_1_extent:2}
   file_2_extent=$( gmt grdinfo -I- $file_2 ); file_2_extent=${file_2_extent:2}

   echo $file_1_extent
   echo $file_2_extent

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

   remainder=$( expr $counter % 2 )



   counter=0
   while [ $counter -lt 4 ]; do    
       if [ $counter -eq 0 ]; then
	   echo "Determining xmin"	
	   if [ $( bc <<< "${file_1_coord_array[$counter]} > ${file_2_coord_array[$counter]}" ) -eq 0 ]; then
	       echo "file 1 has smaller xmin value"		   
	       echo "Adding ${file_1_coord_array[$counter]}"
	       echo
	       xmin=${file_2_coord_array[$counter]}
	   else
	       echo "file 2 has smaller xmin value"
	       echo "Adding ${file_2_coord_array[$counter]}"
	       echo
	       xmin=${file_1_coord_array[$counter]}
	   fi
       elif [ $counter -eq 1 ]; then
	   echo "Determining xmax"	
	   if [ $( bc <<< "${file_1_coord_array[$counter]} < ${file_2_coord_array[$counter]}" ) -eq 0 ]; then
	       echo "file 1 has higher xmax value"		   
	       echo "Adding file_2: ${file_1_coord_array[$counter]}"
	       echo
	       xmax=${file_2_coord_array[$counter]}
	   else
	       echo "file 2 has higher xmax value"
	       echo "Adding file_1: ${file_2_coord_array[$counter]}"
	       echo
	       xmax=${file_1_coord_array[$counter]}
	   fi
       elif [ $counter -eq 2 ]; then
	   echo "Determining ymin"	
	   if [ $( bc <<< "${file_1_coord_array[$counter]} > ${file_2_coord_array[$counter]}" ) -eq 0 ]; then
	       echo "file 1 has smaller ymin value"		   
	       echo "Adding file_2: ${file_1_coord_array[$counter]}"
	       echo
	       ymin=${file_2_coord_array[$counter]}
	   else
	       echo "file 2 has smaller ymin value"
	       echo "Adding file_1: ${file_2_coord_array[$counter]}"
	       echo
	       ymin=${file_1_coord_array[$counter]}
	   fi
       elif [ $counter -eq 3 ]; then
	   echo "Determining ymax"	
	   if [ $( bc <<< "${file_1_coord_array[$counter]} < ${file_2_coord_array[$counter]}" ) -eq 0 ]; then
	       echo "file 1 has max value"		   
	       echo "Adding file_2: ${file_1_coord_array[$counter]}"
	       echo
	       ymax=${file_2_coord_array[$counter]}
	   else
	       echo "file 2 has max value"		   
	       echo "Adding file_1: ${file_2_coord_array[$counter]}"
	       echo
	       ymax=${file_1_coord_array[$counter]}
	   fi
       fi

       counter=$((counter+1))
   done

   # echo "xmin: $xmin"
   # echo "xmax: $xmax"
   # echo "ymin: $ymin"
   # echo "ymax: $ymax"

   
   cut_filename_1="$filename_1-cut.grd"
   cut_filename_2="$filename_2-cut.grd"   

   diff_filename="diff-$filename_2--$filename_1"


   cd $output_PATH

   gmt grdcut $file_1 -GTemp/$cut_filename_1  -R$xmin/$xmax/$ymin/$ymax -V
   gmt grdcut $file_2 -GTemp/$cut_filename_2  -R$xmin/$xmax/$ymin/$ymax -V

   cd Temp
   gmt grdmath $cut_filename_2 $cut_filename_1 SUB = $output_PATH/$diff_filename.grd -V

   cd ..
   rm -r Temp

fi
