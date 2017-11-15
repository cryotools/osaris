#!/bin/bash


#################################################################
#
# Calculate the sum of fwd and rev unwrapped interferograms.
# 
# Usage: unwrapping-sum.sh file1 file2 output_directory [output_filename]
# 
# Both input files must be in GRD format.
# Output filename needs only to be set when both input files have
# the same name (e.g. multiple unwrap_mask_ll.grd files).
# 
################################################################


if [ $# -lt 3 ]; then
    echo
    echo "Usage: unwrapping-sum.sh file1 file2 output_directory [output_filename]"  
    echo
else


    # Check whether .grd files where provided
    if [ ! -f $1 ]; then
	echo
	echo "ERROR: Cannot open $1. Please provide file."
	echo
	exit 1
    else

	if [ ! "${1##*.}" = "grd" ]; then
	    echo
	    echo "ERROR: difference calculation requirers .grd files as input."
	    echo
	    exit 1
	else
	    file_1=$1
	fi
    fi
    
    if [ ! -f $2 ]; then
	echo
	echo "ERROR: Cannot open 21. Please provide file."
	echo
	exit 1
    else

	if [ ! "${2##*.}" = "grd" ]; then
	    echo
	    echo "ERROR: difference calculation requirers .grd files as input."
	    echo
	    exit 1
	else
	    file_2=$2
        fi
    fi

    filename_1=$(basename $file_1 .grd)-1    
    filename_2=$(basename $file_2 .grd)-2
    output_PATH=$3

    if [ $# -eq 4 ]; then
	diff_filename=$4
    else
	diff_filename="diff-$filename_2--$filename_1"
    fi

    mkdir -p $output_PATH
    mkdir -p $output_PATH/Temp

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

   # remainder=$( expr $counter % 2 )


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


   cd $output_PATH

   gmt grdcut $file_1 -GTemp/$cut_filename_1  -R$xmin/$xmax/$ymin/$ymax -V
   gmt grdcut $file_2 -GTemp/$cut_filename_2  -R$xmin/$xmax/$ymin/$ymax -V

   cd Temp
   gmt grdmath $cut_filename_2 $cut_filename_1 ADD = $output_PATH/$diff_filename.grd -V

   cd ..
   # rm -r Temp

fi
