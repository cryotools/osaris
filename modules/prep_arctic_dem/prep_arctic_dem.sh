#!/usr/bin/env bash

######################################################################
#
# Module to prepare ArcitcDEM data for OSARIS
#
# Activate the module in the main config file using the preprocessing
# hook. Alternatively, run in standalone mode from the module folder.
# Usage: prep_arctic_dem.sh path_to_config_file
# 
# The config file must be located within the 'config' folder of OSARIS.
# Get started by copying the template configuration file from the module 
# folder to the OSARIS config folder and fit it to your needs.
#
# Further information on ArcticDEM and a shapefile with tile numbers
# are available at https://www.pgc.umn.edu/data/arcticdem/
#
# David Loibl, 2017
#
#####################################################################

start=`date +%s`

function batch_untar {
    if [ $# -lt 3 ]; then
	echo "Wrong parameter count for batch untar."
	exit 4
    fi

    i=$1
    j=$2
    dem_output_PATH=$3

    dirname=${i}_$j
    # echo $dirname
    if [ -d "$dirname" ]; then
	echo; echo "Extracting data from directory ${i}_$j"
	cd $dirname
	for tar_file in $( ls *.tar* ); do
	    case "$tar_file" in
		*.gz | *.tgz ) 
		    # it's gzipped
		    tar -xzvf $tar_file  -C $dem_output_PATH/temp/ --wildcards --no-anchored '*dem.tif'
		    ;;
		*)
		    tar -xvf $tar_file  -C $dem_output_PATH/temp/ --wildcards --no-anchored '*dem.tif'
		    # it's not
		    ;;
	    esac		    
	done		
	cd ..
    else
	echo "Directory ${i}_$j does not exist. Skipping ..."
    fi
}

if [ $# -eq 0 ]; then
    echo
    echo "Usage: prep_artic_dem.sh path_to_config_file"  
    echo
    exit 1
elif [ ! -f "$1/prep_arctic_dem.config" ]; then
    echo
    echo "Cannot open $1/prep_arctic_dem.config. Please provide a valid config file in the OSARIS config folder."
    echo
    exit 2
else
    
    echo; echo "Processing ArcticDEM"
    config_PATH=$1
    
    source $config_PATH/prep_arctic_dem.config

    # Test if configuration is valid
    if [ ! -d $input_mosaic_PATH ]; then
	echo "Input folder $input_MOSAIC not found. Exiting."
	exit 3
    fi

    rm -rf $dem_output_PATH/temp; mkdir -p $dem_output_PATH/temp

    cd $dem_output_PATH
    if [ -f "merged_dem.tif" ]; then
	echo "File 'merged_dem.tif' already exists. Overwrite? (y/n)"
	read delete_file
	if [ "$delete_file" == "y" ]; then
	    rm merged_dem.tif
	    echo "Overwriting 'merged_dem.tif' ..."
	elif [ "$delete_file" == "n" ]; then
	    echo "Please rename/move merged_dem.tif and restart the script."
	    exit 1
	else
	    echo "Choose 'y' (yes) or 'n' (no). It's not this hard, is it?"
	    exit 1
	fi
    fi


    cd $input_mosaic_PATH

    i=$row_min
    while [ "$i" -le "$row_max" ]; do
	j=$col_min
	while [ "$j" -le "$col_max" ]; do
	    # untar files to target folder

	    batch_untar $i $j $dem_output_PATH

	    j=$(( $j + 1 ))
	done

	# Process single_cols if defined in config
	if [ ! -z ${single_col+x} ]; then
	    col2add=${single_col:0:2}	  
	    batch_untar $i $col2add $dem_output_PATH
	fi

	i=$(( $i +1 ))
    done

    cd $dem_output_PATH/temp
    k=0

    i=$row_min
    prev_row=-1
    while [ "$i" -le "$row_max" ]; do
	j=$col_min
	while [ "$j" -le "$col_max" ]; do
	    # Check if a new row was started. If true, append previous row to merged DEM.
	    if [ "$i" -gt "$prev_row" ] && [ $prev_row -ge 0 ]; then
		if [ ! -f "../merged_dem.grd" ]; then
		    echo; echo "Row $prev_row completed."; echo
		    cp merged_dem_row${prev_row}.grd ../merged_dem.grd		    
		else
		    echo; echo "Row $prev_row completed. Merging to DEM ..."; echo
		    gmt grdpaste merged_dem_row${prev_row}.grd ../merged_dem.grd -G../merged_dem.grd -V
		fi
	    fi

	    echo; echo "Processing $i $j"
	    gmt grdsample ${i}_${j}_1_1_5m_v2.0_reg_dem.tif -I${scale_factor} -G${i}_${j}_1_1_dem3.grd -V
	    gmt grdsample ${i}_${j}_1_2_5m_v2.0_reg_dem.tif -I${scale_factor} -G${i}_${j}_1_2_dem3.grd -V
	    gmt grdsample ${i}_${j}_2_1_5m_v2.0_reg_dem.tif -I${scale_factor} -G${i}_${j}_2_1_dem3.grd -V
	    gmt grdsample ${i}_${j}_2_2_5m_v2.0_reg_dem.tif -I${scale_factor} -G${i}_${j}_2_2_dem3.grd -V
	    gmt grdpaste ${i}_${j}_1_1_dem3.grd ${i}_${j}_1_2_dem3.grd -Gtemp_merge_1.grd -V
	    gmt grdpaste ${i}_${j}_2_1_dem3.grd ${i}_${j}_2_2_dem3.grd -Gtemp_merge_2.grd -V
	    if [ ! -f "merged_dem_row${i}.grd" ]; then
		gmt grdpaste temp_merge_1.grd temp_merge_2.grd -Gmerged_dem_row${i}.grd -V
	    else
		gmt grdpaste temp_merge_1.grd temp_merge_2.grd -Gtemp_merge_${i}_${j}.grd -V
		gmt grdpaste temp_merge_${i}_${j}.grd merged_dem_row${i}.grd -Gmerged_dem_row${i}.grd -V                
	    fi

	    # rm temp_merge_*
	    prev_row=$i

	    j=$(( $j + 1 ))
	done

	if [ ! -z ${single_col+x} ]; then

	    col2add=${single_col:0:2}
	    line=${single_col:3:1}

	    gmt grdsample ${i}_${col2add}_${line}_1_5m_v2.0_reg_dem.tif -I${scale_factor} -G${i}_${col2add}_${line}_1_dem3.grd -V
	    gmt grdsample ${i}_${col2add}_${line}_2_5m_v2.0_reg_dem.tif -I${scale_factor} -G${i}_${col2add}_${line}_2_dem3.grd -V
	    gmt grdpaste ${i}_${col2add}_${line}_1_dem3.grd ${i}_${col2add}_${line}_2_dem3.grd -Gtemp_merge_singlecol.grd -V
	    if [ $i -eq "$row_min" ]; then
		mv temp_merge_singlecol.grd merged_dem_singlecol.grd
	    else
		gmt grdpaste temp_merge_singlecol.grd merged_dem_singlecol.grd -Gmerged_dem_singlecol.grd -V 
	    fi
	fi
	
	
	if [ "$i" -eq "$row_max" ]; then
	    # Last row reached, put everything together ...
	    
	    echo; echo "Row $i completed. Merging to DEM ..."; echo
	    gmt grdpaste merged_dem_row${row_max}.grd ../merged_dem.grd -G../merged_dem.grd -V 

	    if [ ! -z ${single_col+x} ]; then
		# If single_col active, merge that, too ...
		gmt grdpaste merged_dem_singlecol.grd ../merged_dem.grd -G../merged_dem.grd -V 
	    fi

	    cd ..
	    gmt grdproject merged_dem.grd -I -Js-45/90/70/1:1 -C -F -Gdem.grd -V

	    echo; echo
	    echo "Cleaning up"
	    rm -r temp
	    rm merged_dem.grd
	    echo; echo

	    end=`date +%s`

	    runtime=$((end-start))

	    printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n' $(($runtime/86400)) $(($runtime%86400/3600)) $(($runtime%3600/60)) $(($runtime%60))
	    echo

	    exit 1
	else
	    i=$(( $i +1 ))
	fi
    done

fi


