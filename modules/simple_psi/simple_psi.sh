#!/bin/bash

######################################################################
#
# OSARIS module to identify persitant scatterers (simple)
#
#
#
# David Loibl, 2017
#
#####################################################################

start=`date +%s`


#if [ ! -f "$OSARIS_PATH/config/homogenize_intfs.sh" ]; then
#    echo
#    echo "$OSARIS_PATH/config/homogenize_intfs.config is not a valid configuration file"  
#    echo
#    exit 2
#else
#    source $OSARIS_PATH/config/homogenize_intfs.config


echo; echo "Simple Persistent Scatterer Identification"

psi_input_PATH="$output_PATH/Pairs-forward/F3"
echo "PSI input path: $psi_input_PATH"
# "/data/scratch/loibldav/GSP/Golubin_107_4/Output/Pairs-forward"

psi_output_PATH="$output_PATH/PSI"
echo "PSI ouput path: $psi_output_PATH"
psi_threshold="0.2"

mkdir -p $psi_output_PATH/cut

cd $psi_input_PATH

psi_base_PATH=$( pwd )
folders=($( ls -d */ ))

psi_count=1


for folder in "${folders[@]}"; do   
    folder=${folder::-1}
    if [ -f "$folder/corr_ll.grd" ]; then
	if [ "$psi_count" -eq 1 ]; then
	    echo "First folder $folder"
	elif [ "$psi_count" -eq 2 ]; then
	    # echo "grdxtremes=($(grdminmax $psi_base_PATH/$prev_folder/corr_ll.grd $psi_base_PATH/$folder/corr_ll.grd))"



	    # Find min and max x and y values for a grd file.
	    # Input parameters: the two grd files to evaluate.
	    # Output: xmin xmax ymin ymax

	    file_1=$psi_base_PATH/$prev_folder/corr_ll.grd
	    file_2=$psi_base_PATH/$folder/corr_ll.grd

	    file_1_extent=$( gmt grdinfo -I- $file_1 ); file_1_extent=${file_1_extent:2}
	    file_2_extent=$( gmt grdinfo -I- $file_2 ); file_2_extent=${file_2_extent:2}

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

	    remainder=$( expr $counter % 2 )

	    counter=0
	    while [ $counter -lt 4 ]; do    
		if [ $counter -eq 0 ]; then
		    # Determining xmin
		    if [ $( echo "${file_1_coord_array[$counter]} > ${file_2_coord_array[$counter]}" | bc -l ) -eq 0 ]; then
			xmin=${file_2_coord_array[$counter]}
		    else
			xmin=${file_1_coord_array[$counter]}
		    fi
		elif [ $counter -eq 1 ]; then
		    # Determining xmax
		    if [ $( echo "${file_1_coord_array[$counter]} < ${file_2_coord_array[$counter]}" | bc -l ) -eq 0 ]; then
			xmax=${file_2_coord_array[$counter]}
		    else
			xmax=${file_1_coord_array[$counter]}
		    fi
		elif [ $counter -eq 2 ]; then
		    # Determining ymin 
		    if [ $( echo "${file_1_coord_array[$counter]} > ${file_2_coord_array[$counter]}" | bc -l ) -eq 0 ]; then
			ymin=${file_2_coord_array[$counter]}
		    else
			ymin=${file_1_coord_array[$counter]}
		    fi
		elif [ $counter -eq 3 ]; then
		    # Determining ymax 
		    if [ $( echo "${file_1_coord_array[$counter]} < ${file_2_coord_array[$counter]}" | bc -l ) -eq 0 ]; then
			ymax=${file_2_coord_array[$counter]}
		    else
			ymax=${file_1_coord_array[$counter]}
		    fi
		fi

		counter=$((counter+1))
	    done
	    echo "Initial coord set: $xmin/$xmax/$ymin/$ymax"

	else

	    # Find min and max x and y values for a grd file.
	    # Input parameters: the two grd files to evaluate.
	    # Output: xmin xmax ymin ymax

	    file_1=$psi_base_PATH/$prev_folder/corr_ll.grd
	    file_2=$psi_base_PATH/$folder/corr_ll.grd

	    file_1_extent=$( gmt grdinfo -I- $file_1 ); file_1_extent=${file_1_extent:2}
	    file_2_extent=$( gmt grdinfo -I- $file_2 ); file_2_extent=${file_2_extent:2}

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

	    remainder=$( expr $counter % 2 )

	    counter=0
	    while [ $counter -lt 4 ]; do    
		if [ $counter -eq 0 ]; then
		    # Determining xmin
		    if [ $( echo "${file_1_coord_array[$counter]} > ${file_2_coord_array[$counter]}" | bc -l ) -eq 0 ]; then
			xmin_local=${file_2_coord_array[$counter]}
		    else
			xmin_local=${file_1_coord_array[$counter]}
		    fi
		elif [ $counter -eq 1 ]; then
		    # Determining xmax
		    if [ $( echo "${file_1_coord_array[$counter]} < ${file_2_coord_array[$counter]}" | bc -l ) -eq 0 ]; then
			xmax_local=${file_2_coord_array[$counter]}
		    else
			xmax_local=${file_1_coord_array[$counter]}
		    fi
		elif [ $counter -eq 2 ]; then
		    # Determining ymin 
		    if [ $( bc <<< "${file_1_coord_array[$counter]} > ${file_2_coord_array[$counter]}" ) -eq 0 ]; then
			ymin_local=${file_2_coord_array[$counter]}
		    else
			ymin_local=${file_1_coord_array[$counter]}
		    fi
		elif [ $counter -eq 3 ]; then
		    # Determining ymax 
		    if [ $( bc <<< "${file_1_coord_array[$counter]} < ${file_2_coord_array[$counter]}" ) -eq 0 ]; then
			ymax_local=${file_2_coord_array[$counter]}
		    else
			ymax_local=${file_1_coord_array[$counter]}
		    fi
		fi

		counter=$((counter+1))
	    done
	    
	    if (( $(echo "$xmin < $xmin_local" | bc -l) ))  && (( $(echo "$xmin_local != 0" | bc -l) )); then echo "New xmin value found: $xmin_local"; xmin=$xmin_local; fi
	    if (( $(echo "$xmax > $xmax_local" | bc -l) ))  && (( $(echo "$xmax_local != 0" | bc -l) )); then echo "New xmax value found: $xmax_local"; xmax=$xmax_local; fi
	    if (( $(echo "$ymin < $ymin_local" | bc -l) ))  && (( $(echo "$ymin_local != 0" | bc -l) )); then echo "New ymin value found: $ymin_local"; ymin=$ymin_local; fi
	    if (( $(echo "$ymax > $ymax_local" | bc -l) ))  && (( $(echo "$ymax_local != 0" | bc -l) )); then echo "New ymax value found: $ymax_local"; ymax=$ymax_local; fi

	    echo "Updated coord set: $xmin/$xmax/$ymin/$ymax"
	fi
	
	

	prev_folder=$folder
	psi_count=$((psi_count+1))
    else
	echo "No coherence file in folder $folder - skipping ..."
    fi
done

echo; echo "Final coord set: $xmin/$xmax/$ymin/$ymax"

for folder in "${folders[@]}"; do           
    if [ -f "${folder::-1}/corr_ll.grd" ]; then
	gmt grdcut $folder/corr_ll.grd -G$psi_output_PATH/cut/corr_cut_${folder::-1}.grd  -R$xmin/$xmax/$ymin/$ymax -V
	gmt grdclip $psi_output_PATH/cut/corr_cut_${folder::-1}.grd -G$psi_output_PATH/cut/corr_thres_${folder::-1}.grd -Sb${psi_threshold}/NaN -V

    else
	echo "No coherence file in folder $folder - skipping ..."
    fi
done


cd $psi_output_PATH/cut
rm corr_cut*
cut_files=($(ls *.grd))
cut_files_count=1
for cut_file in "${cut_files[@]}"; do
    if [ "$cut_files_count" -eq 1 ]; then
	echo "First file $cut_file"
    elif [ "$cut_files_count" -eq 2 ]; then	
	echo "Addition of coherence from $cut_file and $prev_cut_file ..."
	gmt grdmath $cut_file $prev_cut_file ADD -V = $psi_output_PATH/corr_sum.grd
    else
	echo "Adding coherence from $cut_file ..."
	gmt grdmath $cut_file $psi_output_PATH/corr_sum.grd ADD -V = $psi_output_PATH/corr_sum.grd
    fi

    prev_cut_file=$cut_file
    cut_files_count=$((cut_files_count+1))
done

gmt grdmath $psi_output_PATH/corr_sum.grd $psi_count DIV -V = $psi_output_PATH/corr_arithmean.grd 

# Write coords of max coherence points to file for further processing ..
gmt grdinfo -M -V $psi_output_PATH/corr_sum.grd | grep z_max | awk '{ print $16,$19 }' > $psi_output_PATH/ps_coords.xy


echo; echo
echo "Cleaning up"
rm -r temp
rm merged_dem.grd
echo; echo

end=`date +%s`

runtime=$((end-start))

printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n' $(($runtime/86400)) $(($runtime%86400/3600)) $(($runtime%3600/60)) $(($runtime%60))
echo



# fi


