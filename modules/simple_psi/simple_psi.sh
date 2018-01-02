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

function grdminmax {
    # Find min and max x and y values for a grd file.
    # Input parameters: the two grd files to evaluate.
    # Output: xmin xmax ymin ymax

    file_1=$0
    file_2=$1

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
	    if [ $( bc <<< "${file_1_coord_array[$counter]} > ${file_2_coord_array[$counter]}" ) -eq 0 ]; then
		xmin=${file_2_coord_array[$counter]}
	    else
		xmin=${file_1_coord_array[$counter]}
	    fi
	elif [ $counter -eq 1 ]; then
	    # Determining xmax
	    if [ $( bc <<< "${file_1_coord_array[$counter]} < ${file_2_coord_array[$counter]}" ) -eq 0 ]; then
		xmax=${file_2_coord_array[$counter]}
	    else
		xmax=${file_1_coord_array[$counter]}
	    fi
	elif [ $counter -eq 2 ]; then
	    # Determining ymin 
	    if [ $( bc <<< "${file_1_coord_array[$counter]} > ${file_2_coord_array[$counter]}" ) -eq 0 ]; then
		ymin=${file_2_coord_array[$counter]}
	    else
		ymin=${file_1_coord_array[$counter]}
	    fi
	elif [ $counter -eq 3 ]; then
	    # Determining ymax 
	    if [ $( bc <<< "${file_1_coord_array[$counter]} < ${file_2_coord_array[$counter]}" ) -eq 0 ]; then
		ymax=${file_2_coord_array[$counter]}
	    else
		ymax=${file_1_coord_array[$counter]}
	    fi
	fi

	counter=$((counter+1))
    done

    echo $xmin
    echo $xmax
    echo $ymin
    echo $ymax
}

echo; echo "Simple Persistant Scatterer Identification"

psi_input_PATH="/data/scratch/loibldav/GSP/Golubin_107_4/Output/Pairs-forward"
psi_output_PATH="/data/scratch/loibldav/GSP/Golubin_107_4/Output/PSI/"

mkdir -p $psi_output_PATH/cut

cd $psi_input_PATH

folders=($( ls -r ))

psi_count=1

for folder in "${folders[@]}"; do   
    if [ -f "$folder/corr_ll.grd" ]; then
	if [ "$psi_count" -eq 1 ]; then
	    echo "First folder $folder"
	elif [ "$psi_count" -eq 2 ]; then
	    grdxtremes=($(grdminmax $prev_folder/corr_ll.grd $folder/corr_ll.grd))
	    echo "grdxtremes: $grdextremes"
	    echo "{grdxtremes[@]}: ${grdxtremes[@]}"
	    echo "{grdxtremes[1]}: ${grdxtremes[1]}"
	    xmin=${grdxtremes[0]}
	    xmax=${grdxtremes[1]}
	    ymin=${grdxtremes[2]}
	    ymax=${grdxtremes[3]}
	else 
	    grdxtremes=($(grdminmax $prev_folder/corr_ll.grd $folder/corr_ll.grd))
	    echo "grdxtremes: $grdxtremes"
	    echo "{grdxtremes[@]}: ${grdxtremes[@]}"
	    echo "{grdxtremes[1]}: ${grdxtremes[1]}"
	    if [ "$xmin" -lt "${grdxtremes[0]}" ] %% [ ! "${grdxtremes[0]}" -eq 0 ]; then xmin=${grdxtremes[0]}; fi
	    if [ "$xmax" -gt "${grdxtremes[1]}" ] %% [ ! "${grdxtremes[1]}" -eq 0 ]; then xmax=${grdxtremes[1]}; fi
	    if [ "$ymin" -lt "${grdxtremes[2]}" ] %% [ ! "${grdxtremes[2]}" -eq 0 ]; then ymin=${grdxtremes[2]}; fi
	    if [ "$ymax" -gt "${grdxtremes[3]}" ] %% [ ! "${grdxtremes[3]}" -eq 0 ]; then ymax=${grdxtremes[3]}; fi
	    xmax=${grdxtremes[1]}
	    ymin=${grdxtremes[2]}
	    ymax=${grdxtremes[3]}

	fi

	prev_folder=$folder
	psi_count=$((psi_count+1))
    else
	echo "No coherence file in folder $folder - skipping ..."
    fi
done

exit

cd $psi_output_PATH/cut
cut_files=($( ls | grep "\.grd$" ))
cut_files_count=1
for cut_file in "${cut_files[@]}"; do
    if [ "$cut_file_count" -eq 1 ]; then
	echo "First file $cut_file"
    elif [ "$cut_files_count" -eq 2 ]; then
	# gmt grdmath $psi_output_PATH/cut/ $folder/corr_ll.grd ADD -V = $psi_output_PATH/corr_sum.grd
    else
	echo "Adding coherence from $folder ..."
	# gmt grdmath $folder/corr_ll.grd $psi_output_PATH/corr_sum.grd ADD -V = $psi_output_PATH/corr_sum.grd
    fi

    prev_cut_file=$cut_file
    cut_files_count=$((cut_files_count+1))
done

# gmt grdmath $psi_output_PATH/corr_sum.grd $psi_count DIV -V = $psi_output_PATH/corr_arithmean.grd


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


