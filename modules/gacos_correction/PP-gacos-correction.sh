#!/usr/bin/env bash

start=`date +%s`

echo; echo "Starting GACOS correction processing ..."; echo

GACOS_work_PATH=$1
GACOS_output_PATH=$2
GACOS_intf_input_PATH=$3
intf=$4


master_date="${intf:10:8}"
slave_date="${intf:0:8}"
master_grd="$GACOS_work_PATH/GACOS_files/${master_date}.grd"
slave_grd="$GACOS_work_PATH/GACOS_files/${slave_date}.grd"


# Step 1: Time Differencing
echo; echo "Conducting time differencing of GACOS scenes ..."
zpddm_file="$GACOS_work_PATH/${slave_date}-${master_date}.grd"
gmt grdmath $master_grd $slave_grd SUB = "$zpddm_file" -V


# Step 2: Space Differencing
echo; echo "Conducting space differencing of GACOS scenes ..."
szpddm_file="$GACOS_work_PATH/${slave_date}-${master_date}-sd.grd"
zpddm_ps_value=$( gmt grdtrack $GACOS_work_PATH/ref_point.xy -G$zpddm_file )
zpddm_ps_value=$( echo "$zpddm_ps_value" | awk '{ print $3 }' )
echo; echo " PS value: $zpddm_ps_value"
gmt grdmath $zpddm_file $zpddm_ps_value SUB = $szpddm_file -V

# Step 3: Apply the correction
echo; echo "Applying GACOS correction to interferogram"
echo "$GACOS_intf_input_PATH/$intf"

# Cut GACOS diff file and phase file to same extent

file_1="$szpddm_file"
file_2="$GACOS_intf_input_PATH/$intf"

file_1_extent=$( gmt grdinfo -I- $file_1 ); file_1_extent=${file_1_extent:2}
file_2_extent=$( gmt grdinfo -I- $file_2 ); file_2_extent=${file_2_extent:2}

file_1_coord_string=$( echo $file_1_extent | tr "/" "\n")
file_2_coord_string=$( echo $file_2_extent | tr "/" "\n")

echo; echo "File 1 coordinate string: "
echo "$file_1_coord_string"
echo; echo "File 2 coordinate string: "
echo "$file_2_coord_string"
echo

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

# Check and correct for longitudes > 180°
#if [ $( echo "$xmin > 180" | bc -l ) -eq 1 ]; then xmin=$( echo "$xmin - 360" | bc -l ); fi
#if [ $( echo "$xmax > 180" | bc -l ) -eq 1 ]; then xmax=$( echo "$xmax - 360" | bc -l ); fi

echo; echo "  The common minimum boundary box for the files"
echo "  - $szpddm_file and"
echo "  - $GACOS_intf_input_PATH/$intf"
echo "  is $xmin/$xmax/$ymin/$ymax"

echo; echo "gmt grdsample $szpddm_file -G${szpddm_file::-4}-cut.grd -R$xmin/$xmax/$ymin/$ymax `gmt grdinfo -I $GACOS_intf_input_PATH/$intf` -V"
gmt grdsample $szpddm_file -G${szpddm_file::-4}-cut.grd -R$xmin/$xmax/$ymin/$ymax `gmt grdinfo -I $GACOS_intf_input_PATH/$intf` -V

echo; echo "gmt grdsample $GACOS_intf_input_PATH/$intf -G$GACOS_work_PATH/cut_intfs/$intf `gmt grdinfo -I- ${szpddm_file::-4}-cut.grd` `gmt grdinfo -I ${szpddm_file::-4}-cut.grd` -V"
gmt grdsample $GACOS_intf_input_PATH/$intf -G$GACOS_work_PATH/cut_intfs/$intf \
    `gmt grdinfo -I- ${szpddm_file::-4}-cut.grd` \
    `gmt grdinfo -I ${szpddm_file::-4}-cut.grd` -V


corrected_phase_file="$GACOS_output_PATH/${slave_date}--${master_date}-gacoscorr.grd"
gmt grdmath $GACOS_work_PATH/cut_intfs/$intf ${szpddm_file::-4}-cut.grd SUB = $corrected_phase_file -V



if [ -f $UCM_output_PATH/$UCM_file ]; then status_UCM=1; else status_UCM=0; fi

end=`date +%s`
runtime=$((end-start))

echo "${high_corr_file:7:8}-${high_corr_file:30:8} ${corr_file:7:8}-${corr_file:30:8} $SLURM_JOB_ID $runtime $status_UCM" >> $output_PATH/Reports/PP-UCM-stats.tmp

printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n' $(($runtime/86400)) $(($runtime%86400/3600)) $(($runtime%3600/60)) $(($runtime%60))
