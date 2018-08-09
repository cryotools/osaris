#!/bin/bash

######################################################################
#
# OSARIS module to apply correction for atmospheric delays using GACOS 
# data. For more information on GACOS see:
# 
# Yu, C., N. T. Penna, and Z. Li (2017), Generation of real-time mode 
# high-resolution water vapor fields from GPS observations, 
# J. Geophys. Res. Atmos., 122, 2008–2025.
# Yu, C., Z. Li, and N. T. Penna (2017), Interferometric synthetic 
# aperture radar atmospheric correction using a GPS-based iterative 
# tropospheric decomposition model, Remote Sens. Environ.
#
# Obtain GACOS data from http://ceg-research.ncl.ac.uk/v2/gacos/
# and provide the path to the data in the gacos_correction.config
# file in $OSARIS_PATH/config
#
# Input:
# - Stable ground point identified by SGP_indentification module
# - Unwrapped interferograms
# - GACOS data for each scene data in the timeseries
#
# David Loibl, 2018
#
#####################################################################

module_name="gacos_correction"

if [ ! -f "$OSARIS_PATH/config/${module_name}.config" ]; then
    echo
    echo "Cannot open ${module_name}.config in the OSARIS config folder. Please provide a valid config file."
    echo
else
    # Start runtime timer
    gacos_start=`date +%s`

    # Include the config file
    source $OSARIS_PATH/config/${module_name}.config



    ############################
    # Module actions start here
    
    echo "Starting the GACOS Correction module ..."

    
    if [ ! -z "$unwrp_intf_PATH" ]; then
	echo "Variable 'unwrp_intf_PATH' not set in config/${module_name}.config."
	echo "Trying default path $output_PATH/Pairs-forward/Interferograms-unwrapped ..."
	unwrp_intf_PATH="$output_PATH/Pairs-forward/Interferograms-unwrapped"
    fi
    
    GACOS_work_PATH="$work_PATH/GACOS_correction/"
    GACOS_output_PATH="$output_PATH/GACOS-corrected"
    mkdir -p $GACOS_work_PATH/GACOS_files
    mkdir -p $GACOS_work_PATH/cut_intfs
    mkdir -p $GACOS_output_PATH
    
    # TODO: read from .PRM files in Processing/raw
    radar_wavelength="0.554658"


    # Check if all data is available

    # (i) Stable ground point

    # Check how to deal with the reference point depending of value of config var $harmonize_input
    if [ -z $reference_point ]; then
	echo "Variable reference_point not set in ${module_name}.config "
	echo "Trying to use results from SGPI ..."; echo

	#########
	## TODO: Adapt the whole following if statement to new path after renaming to SGPI module and removing swaths in post-processing stage ...
	#########

	if [ ! -f "$output_PATH/PSI/ps_coords-F${swath}.xy" ]; then
	    echo; echo "ERROR: Cannot open $output_PATH/PSI/ps_coords-F${swath}.xy - Please run the simple_PSI module before executing gacos_correction. Exiting ..."
	    check_ps=0
	else
	    check_ps=1
	    sg_lon=($( cat $output_PATH/PSI/ps_coords-F$swath.xy | awk '{ print $1 }' ))
	    sg_lat=($( cat $output_PATH/PSI/ps_coords-F$swath.xy | awk '{ print $2 }' ))
	    echo "${sg_lon} ${sg_lat}" > $GACOS_work_PATH/ref_point.xy
	fi
    else	    
	echo "Variable reference_point set to $reference_point in ${module_name}.config " 
	echo "Validating coordinates ..."
	ref_point_array=(${ref_point_xy_coords//\// })	    
	sg_lon=${ref_point_array[0]}
	sg_lat=${ref_point_array[1]}
	echo "${sg_lon} ${sg_lat}" > $GACOS_work_PATH/ref_point.xy
	check_ps=1
    fi


    # (ii) Unwrapped interferograms
    if [ $harmonize_input_grids -eq 0 ]; then
	echo; echo "Interferogram stack harmonization disabled in ${module_name}.config "
	echo " -> Assuming interferograms in $unwrp_intf_PATH are harmonized to reference point ..."; echo
	GACOS_intf_input_PATH="$unwrp_intf_PATH"
    else
	echo; echo "Harmonizing input interferogram time series ... "
	GACOS_intf_input_PATH="$unwrp_intf_PATH"
	mkdir -p $GACOS_intf_input_PATH
	$OSARIS_PATH/lib/harmonize_grids.sh $unwrp_intf_PATH $sg_lon/$sg_lat $GACOS_intf_input_PATH
    fi

    if [ ! -d "$GACOS_intf_input_PATH" ]; then
	echo; echo "ERROR: Directory $GACOS_intf_input_PATH does not exist. Exiting ..."
	check_ui=0
    else	    
	cd "$GACOS_intf_input_PATH"
	scenes=$( ls *.grd )
	if [ ! -z "$scenes" ]; then
	    for scene in ${scenes[@]}; do 
		echo $ scenes >> $GACOS_work_PATH/intfs.list
		echo ${scene:0:8} >> $GACOS_work_PATH/master_dates.list
		echo ${scene:10:8} >> $GACOS_work_PATH/slave_dates.list
	    done
	    check_ui=1
	else
	    echo; echo "ERROR: No interferogram files in $GACOS_intf_input_PATH. Exiting ..."
	    check_ui=0
	fi
    fi
    
    # (iii) GACOS directory
    if [ ! -d "$gacos_PATH" ]; then
	echo; echo "ERROR: Directory $gacos_PATH does not exist."
	echo "Download data from http://ceg-research.ncl.ac.uk/v2/gacos/ and provide the path to the files in gacos_correction.config."
	echo "Exiting ..."
	check_gs=0
    else
	cd $gacos_PATH
	gacos_files=$( ls *.rsc )
	if [ ! -z "$gacos_files" ]; then
	    for gacos_file in ${gacos_files[@]}; do 
		echo ${gacos_file:0:8} >> $GACOS_work_PATH/gacos_dates.list
	    done		
	    check_gs=1
	else
	    echo; echo "ERROR: No GACOS files in ${gacos_PATH}."
	    echo "Download data from http://ceg-research.ncl.ac.uk/v2/gacos/ and provide the path to the files in gacos_correction.config."
	    echo "Exiting ..."
	    check_gs=0
	fi	    
    fi


    if [ $check_ps -eq 1 ] && [ $check_ui -eq 1 ] && [ $check_gs -eq 1 ]; then #&& [ $check_xml -eq 1 ]
	
	# Calculate factor to convert m to radians:
	# lambda * -4 * PI
	# Minus is to invert the result for subsequent
	radians2m_conversion=$( echo "$radar_wavelength * 4 * 4 * a(1)" | bc -l )
	
	for intf in ${scenes[@]}; do
	    # Cut GACOS data and intfs. to same extent
	    master_date="${intf:10:8}"
	    slave_date="${intf:0:8}"
	    master_grd="$GACOS_work_PATH/GACOS_files/${master_date}.grd"
	    slave_grd="$GACOS_work_PATH/GACOS_files/${slave_date}.grd"

	    # master_incidence_angle=$( cat $GACOS_work_PATH/incidence_angles.list | grep ${master_date} | awk '{ print $2 }' )
	    # slave_incidence_angle=$( cat $GACOS_work_PATH/incidence_angles.list | grep ${slave_date} | awk '{ print $2 }' )
	    
	    echo; echo "Now working on master $master_date / slave $slave_date"

	    if [ ! -f "$master_grd" ]; then
		echo "  Preparing GACOS data for $master_date ..."
		if [ -f "$gacos_PATH/${master_date}.ztd" ]; then
		    echo "  Converting GACOS file $gacos_PATH/${master_date}.ztd to grid file ..."
		    gacos_x_min=$( cat $gacos_PATH/${master_date}.ztd.rsc | grep -e "X_FIRST" | awk '{ print $2 }' )
		    gacos_y_min=$( cat $gacos_PATH/${master_date}.ztd.rsc | grep -e "Y_FIRST" | awk '{ print $2 }' )
		    gacos_x_pxct=$( cat $gacos_PATH/${master_date}.ztd.rsc | grep -e "XMAX" | awk '{ print $2 }' )
		    gacos_y_pxct=$( cat $gacos_PATH/${master_date}.ztd.rsc | grep -e "YMAX" | awk '{ print $2 }' )
		    gacos_x_step=$( cat $gacos_PATH/${master_date}.ztd.rsc | grep -e "X_STEP" | awk '{ print $2 }' )
		    gacos_y_step=$( cat $gacos_PATH/${master_date}.ztd.rsc | grep -e "Y_STEP" | awk '{ print $2 }' )
		    
		    gacos_x_diff=$( echo "$gacos_x_pxct * $gacos_x_step" | bc -l )
		    if [ $( echo "$gacos_x_step < 0" | bc -l ) -eq 1 ] && [ $( echo "$gacos_x_diff > 0" | bc -l ) -eq 1 ]; then
			gacos_x_diff=$( echo "$gacos_x_diff * -1" | bc -l )
			gacos_x_max=$gacos_x_min
			gacos_x_min=$( echo "$gacos_x_min + $gacos_x_diff" | bc -l )
			gacos_x_step=$( echo "$gacos_x_step * -1" | bc -l )
		    elif [ $( echo "$gacos_x_diff < 0" | bc -l ) -eq 1 ]; then
			gacos_x_max=$gacos_x_min
			gacos_x_min=$( echo "$gacos_x_min + $gacos_x_diff" | bc -l )
			gacos_x_step=$( echo "$gacos_x_step * -1" | bc -l )
		    else
			gacos_x_max=$( echo "$gacos_x_min + $gacos_x_diff" | bc -l )
		    fi

		    gacos_y_diff=$( echo "$gacos_y_pxct * $gacos_y_step" | bc -l )
		    if [ $( echo "$gacos_y_step < 0" | bc -l ) -eq 1 ] && [ $( echo "$gacos_y_diff > 0" | bc -l ) -eq 1 ]; then
			gacos_y_diff=$( echo "$gacos_y_diff * -1" | bc -l )
			gacos_y_max=$gacos_y_min
			gacos_y_min=$( echo "$gacos_y_min + $gacos_y_diff" | bc -l )
			gacos_y_step=$( echo "$gacos_y_step * -1" | bc -l )
		    elif [ $( echo "$gacos_y_diff < 0" | bc -l ) -eq 1 ]; then
			gacos_y_max=$gacos_y_min
			gacos_y_min=$( echo "$gacos_y_min + $gacos_y_diff" | bc -l )
			gacos_y_step=$( echo "$gacos_y_step * -1" | bc -l )
		    else
			gacos_y_max=$( echo "$gacos_y_min + $gacos_y_diff" | bc -l )
		    fi			
		    
		    echo; echo "x_min for ${master_date}.ztd: $gacos_x_min"
		    echo "y_min for ${master_date}.ztd: $gacos_y_min"
		    echo "x_pxct for ${master_date}.ztd: $gacos_x_pxct"
		    echo "y_pxct for ${master_date}.ztd: $gacos_y_pxct"
		    echo "x_step for ${master_date}.ztd: $gacos_x_step"
		    echo "y_step for ${master_date}.ztd: $gacos_y_step"
		    echo "x_diff for ${master_date}.ztd: $gacos_x_diff"
		    echo "y_diff for ${master_date}.ztd: $gacos_y_diff"

		    echo "x_max for ${master_date}.ztd: $gacos_x_max"
		    echo "y_max for ${master_date}.ztd: $gacos_y_max"

		    cp $gacos_PATH/${master_date}.ztd $GACOS_work_PATH/GACOS_files
		    
		    echo; echo "  Converting GACOS ztd to grid file ..."
		    echo "gmt xyz2grd $GACOS_work_PATH/GACOS_files/${master_date}.ztd -ZTLf -r -R$gacos_x_min/$gacos_x_max/$gacos_y_min/$gacos_y_max -I$gacos_x_step/$gacos_y_step -G${master_grd::-4}-raw.grd -V"
		    gmt xyz2grd $GACOS_work_PATH/GACOS_files/${master_date}.ztd \
			-ZTLf -r -R$gacos_x_min/$gacos_x_max/$gacos_y_min/$gacos_y_max -I$gacos_x_step/$gacos_y_step -G${master_grd::-4}-raw.grd -V

		    echo; echo "  Converting GACOS file from m to radians ..."
		    # Factor 1000 is to convert from m (GACOS) to mm (GMTSAR)
		    gmt grdmath ${master_grd::-4}-raw.grd $radians2m_conversion DIV 1000 MUL = ${master_grd::-4}-raw-rad.grd -V   
		    # gmt grdmath ${master_grd::-4}-raw.grd 4 MUL PI MUL $radar_wavelength MUL = ${master_grd::-4}-raw-rad.grd -V
		    
		    echo; echo "  Interpolating GACOS grid file to interferogram resolution ..."
		    gmt grdsample ${master_grd::-4}-raw-rad.grd -I0.0001 -G$master_grd -V
		    # `gmt grdinfo -I $output_PATH/Homogenized-Intfs/$intf`
		    # ncdump -h ${master_grd::-4}-raw.grd

		    # echo; echo "  Interpolating GACOS grid file to interferogram resolution ..."
		    # intf_res=$( gmt grdinfo -I $output_PATH/Homogenized-Intfs/$intf )
		    # echo "Intf resolution: $intf_res"
		    # intf_res=${intf_res:2}
		    # intf_res=(${intf_res//\// })
		    
		    # gdalwarp ${master_grd::-4}-raw.grd \
		    #     -te $gacos_x_min $gacos_y_min $gacos_x_max $gacos_y_max \
		    #     -tr ${intf_res[0]} ${intf_res[1]} \
		    #     $master_grd



		    # echo; echo "gmt surface ${master_grd::-4}-raw.grd?x/y/z -R$gacos_x_min/$gacos_x_max/$gacos_y_min/$gacos_y_max -Q -I0.00001/0.00001 -G$master_grd -Vl"
		    # gmt surface ${master_grd::-4}-raw.grd?x/y/z \
		    #     -R$gacos_x_min/$gacos_x_max/$gacos_y_min/$gacos_y_max -Q \
		    #     -I0.00001/0.00001 \
		    #     -G$master_grd -Vl

		    #`gmt grdinfo -I $output_PATH/Homogenized-Intfs/$intf`

		    
		    # echo; echo "gmt blockmedian $GACOS_work_PATH/GACOS_files/${master_date}.ztd \
		    #     -R$gacos_x_min/$gacos_x_max/$gacos_y_min/$gacos_y_max \
		    #     -I${gacos_x_step} -bi3f+L -V > $GACOS_work_PATH/GACOS_files/${master_date}.xyz"; echo

		    # gmt blockmedian $GACOS_work_PATH/GACOS_files/${master_date}.ztd \
		    #     -R$gacos_x_min/$gacos_x_max/$gacos_y_min/$gacos_y_max \
		    #     -I${gacos_x_step} -bi3f+L -V > $GACOS_work_PATH/GACOS_files/${master_date}.xyz

		    # echo; echo "gmt surface $GACOS_work_PATH/GACOS_files/${master_date}.xyz \
		    #     -R$gacos_x_min/$gacos_x_max/$gacos_y_min/$gacos_y_max -Q `gmt grdinfo -I $output_PATH/Homogenized-Intfs/$intf` -T0.3 -N1000 -G$master_grd -r -Vl"; echo

		    # gmt surface $GACOS_work_PATH/GACOS_files/${master_date}.xyz \
		    #     -R$gacos_x_min/$gacos_x_max/$gacos_y_min/$gacos_y_max -Q `gmt grdinfo -I $output_PATH/Homogenized-Intfs/$intf` -T0.3 -N1000 -G$master_grd -r -Vl

		    # gmt surface $GACOS_work_PATH/GACOS_files/${master_date}.ztd \
		    #     -bi3f \
		    #     -R$gacos_x_min/$gacos_x_max/$gacos_y_min/$gacos_y_max \
		    #     -I0.00001/0.00001 \
		    #     -N1000 -G$master_grd -V

 		    
		else
		    echo; echo "ERROR: No GACOS file available for date ${master_date}."
		fi
	    fi

	    if [ ! -f "$slave_grd" ]; then
		echo "  Preparing GACOS data for $slave_date ..."
		if [ -f "$gacos_PATH/${slave_date}.ztd" ]; then
		    echo "  Converting GACOS file $gacos_PATH/${slave_date}.ztd to grid file ..."
		    gacos_x_min=$( cat $gacos_PATH/${slave_date}.ztd.rsc | grep -e "X_FIRST" | awk '{ print $2 }' )
		    gacos_y_min=$( cat $gacos_PATH/${slave_date}.ztd.rsc | grep -e "Y_FIRST" | awk '{ print $2 }' )
		    gacos_x_pxct=$( cat $gacos_PATH/${slave_date}.ztd.rsc | grep -e "XMAX" | awk '{ print $2 }' )
		    gacos_y_pxct=$( cat $gacos_PATH/${slave_date}.ztd.rsc | grep -e "YMAX" | awk '{ print $2 }' )
		    gacos_x_step=$( cat $gacos_PATH/${slave_date}.ztd.rsc | grep -e "X_STEP" | awk '{ print $2 }' )
		    gacos_y_step=$( cat $gacos_PATH/${slave_date}.ztd.rsc | grep -e "Y_STEP" | awk '{ print $2 }' )
		    
		    gacos_x_diff=$( echo "$gacos_x_pxct * $gacos_x_step" | bc -l )
		    if [ $( echo "$gacos_x_step < 0" | bc -l ) -eq 1 ] && [ $( echo "$gacos_x_diff > 0" | bc -l ) -eq 1 ]; then
			gacos_x_diff=$( echo "$gacos_x_diff * -1" | bc -l )
			gacos_x_max=$gacos_x_min
			gacos_x_min=$( echo "$gacos_x_min + $gacos_x_diff" | bc -l )
			gacos_x_step=$( echo "$gacos_x_step * -1" | bc -l )
		    elif [ $( echo "$gacos_x_diff < 0" | bc -l ) -eq 1 ]; then
			gacos_x_max=$gacos_x_min
			gacos_x_min=$( echo "$gacos_x_min + $gacos_x_diff" | bc -l )
			gacos_x_step=$( echo "$gacos_x_step * -1" | bc -l )
		    else
			gacos_x_max=$( echo "$gacos_x_min + $gacos_x_diff" | bc -l )
		    fi

		    gacos_y_diff=$( echo "$gacos_y_pxct * $gacos_y_step" | bc -l )
		    if [ $( echo "$gacos_y_step < 0" | bc -l ) -eq 1 ] && [ $( echo "$gacos_y_diff > 0" | bc -l ) -eq 1 ]; then
			gacos_y_diff=$( echo "$gacos_y_diff * -1" | bc -l )
			gacos_y_max=$gacos_y_min
			gacos_y_min=$( echo "$gacos_y_min + $gacos_y_diff" | bc -l )
			gacos_y_step=$( echo "$gacos_y_step * -1" | bc -l )
		    elif [ $( echo "$gacos_y_diff < 0" | bc -l ) -eq 1 ]; then
			gacos_y_max=$gacos_y_min
			gacos_y_min=$( echo "$gacos_y_min + $gacos_y_diff" | bc -l )
			gacos_y_step=$( echo "$gacos_y_step * -1" | bc -l )
		    else
			gacos_y_max=$( echo "$gacos_y_min + $gacos_y_diff" | bc -l )
		    fi
		    
		    echo; echo "x_min for ${master_date}.ztd: $gacos_x_min"
		    echo "y_min for ${master_date}.ztd: $gacos_y_min"
		    echo "x_pxct for ${master_date}.ztd: $gacos_x_pxct"
		    echo "y_pxct for ${master_date}.ztd: $gacos_y_pxct"
		    echo "x_step for ${master_date}.ztd: $gacos_x_step"
		    echo "y_step for ${master_date}.ztd: $gacos_y_step"
		    echo "x_diff for ${master_date}.ztd: $gacos_x_diff"
		    echo "y_diff for ${master_date}.ztd: $gacos_y_diff"

		    echo "x_max for ${master_date}.ztd: $gacos_x_max"
		    echo "y_max for ${master_date}.ztd: $gacos_y_max"

		    cp $gacos_PATH/${slave_date}.ztd $GACOS_work_PATH/GACOS_files

		    echo; echo "  Converting GACOS ztd to grid file ..."
		    
		    echo "gmt xyz2grd $GACOS_work_PATH/GACOS_files/${slave_date}.ztd -ZTLf -r -R$gacos_x_min/$gacos_x_max/$gacos_y_min/$gacos_y_max -I$gacos_x_step/$gacos_y_step -G${slave_grd::-4}-raw.grd -V"
		    gmt xyz2grd $GACOS_work_PATH/GACOS_files/${slave_date}.ztd \
			-ZTLf -r -R$gacos_x_min/$gacos_x_max/$gacos_y_min/$gacos_y_max -I$gacos_x_step/$gacos_y_step -G${slave_grd::-4}-raw.grd -V

		    echo; echo "  Converting GACOS file from m to radians ..."
		    # Factor 1000 is to convert from m (GACOS) to mm (GMTSAR)
		    gmt grdmath ${master_grd::-4}-raw.grd $radians2m_conversion DIV 1000 MUL = ${master_grd::-4}-raw-rad.grd -V   

		    echo; echo "  Interpolating GACOS grid file to interferogram resolution ..."
		    gmt grdsample ${slave_grd::-4}-raw.grd -I0.0001 -G$slave_grd -V

		    # ncdump -h ${slave_grd::-4}-raw.grd

		    # GDAL attempt
		    # intf_res=$( gmt grdinfo -I $output_PATH/Homogenized-Intfs/$intf )
		    # echo "Intf resolution: $intf_res"
		    # intf_res=${intf_res:2}
		    # intf_res=(${intf_res//\// })
		    
		    # gdalwarp ${slave_grd::-4}-raw.grd \
		    #     -te $gacos_x_min $gacos_y_min $gacos_x_max $gacos_y_max \
		    #     -tr ${intf_res[0]} ${intf_res[1]} \
		    #     $slave_grd



		    # gmt blockmedian $GACOS_work_PATH/GACOS_files/${slave_date}.ztd \
		    #     -R$gacos_x_min/$gacos_x_max/$gacos_y_min/$gacos_y_max \
		    #     -I$gacos_x_step/$gacos_y_step -bi3f -V > $GACOS_work_PATH/GACOS_files/${slave_date}.xyz

		    # gmt surface $GACOS_work_PATH/GACOS_files/${slave_date}.xyz \
		    #     -R$gacos_x_min/$gacos_x_max/$gacos_y_min/$gacos_y_max -Q `gmt grdinfo -I $output_PATH/Homogenized-Intfs/$intf` -T0.3 -N1000 -G$slave_grd -r -Vl



		    # gmt surface -G$slave_grd ${slave_grd::-4}-raw.grd?x/y/z \
		    #     -R$gacos_x_min/$gacos_x_max/$gacos_y_min/$gacos_y_max -Q -T0.3 -N1000 \
		    #     -I0.0001/0.0001 \
		    #     -Vl

		    # echo; echo "gmt surface $GACOS_work_PATH/GACOS_files/${slave_date}.ztd -bi3f -R$gacos_x_min/$gacos_x_max/$gacos_y_min/$gacos_y_max -Q `gmt grdinfo -I $output_PATH/Homogenized-Intfs/$intf` -T0.3 -G$slave_grd -N1000 -r -Vl"; echo 

		    # gmt surface $GACOS_work_PATH/GACOS_files/${slave_date}.ztd \
		    #     -bi3f \
		    #     -R$gacos_x_min/$gacos_x_max/$gacos_y_min/$gacos_y_max -Q `gmt grdinfo -I $output_PATH/Homogenized-Intfs/$intf` -T0.3 -N1000 -r -Vl



		    # if [ -f "$gacos_PATH/${slave_date}.ztd" ]; then
		    # 	cp $gacos_PATH/${slave_date}.ztd $GACOS_work_PATH/GACOS_files
		    # 	gmt xyz2grd $GACOS_work_PATH/GACOS_files/$gacos_slave \
		    # 	    -ZTLf -r -R$gacos_extent -G$slave_grd -V
		    # 	# `gmt grdinfo -I- $output_PATH/Homogenized-Intfs/$intf` `gmt grdinfo -I $output_PATH/Homogenized-Intfs/$intf`
		else
		    echo; echo "ERROR: No GACOS file available for date ${slave_date}."
		fi

	    fi

	    # gacos_extent=$( gmt grdinfo -I- $GACOS_work_PATH/GACOS_files/${intf:0:8}.grd ); gacos_extent=${gacos_extent:2}
	    # intf_extent=file_1_extent=$( gmt grdinfo -I- $file_1 ); file_1_extent=${file_1_extent:2}

	    



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

	    echo; echo "  The common minimum boundary box for the files"
	    echo "  - $szpddm_file and"
	    echo "  - $GACOS_intf_input_PATH/$intf"
	    echo "  is $xmin/$xmax/$ymin/$ymax"
	    echo; echo "gmt grdcut $szpddm_file -G${szpddm_file::-4}-cut.grd -R$xmin/$xmax/$ymin/$ymax `gmt grdinfo -I $GACOS_intf_input_PATH/$intf` -V"; echo
	    #  `gmt grdinfo -I $output_PATH/Homogenized-Intfs/$intf`

	    gmt grdsample $szpddm_file -G${szpddm_file::-4}-cut.grd -R$xmin/$xmax/$ymin/$ymax `gmt grdinfo -I $GACOS_intf_input_PATH/$intf` -V
	    gmt grdsample $GACOS_intf_input_PATH/$intf -G$GACOS_work_PATH/cut_intfs/$intf \
		`gmt grdinfo -I- ${szpddm_file::-4}-cut.grd` \
		`gmt grdinfo -I ${szpddm_file::-4}-cut.grd` -V
	    # gmt grdcut $szpddm_file -G${szpddm_file::-4}-cut.grd -R$xmin/$xmax/$ymin/$ymax -V
	    # gmt grdcut $output_PATH/Homogenized-Intfs/$intf -G$GACOS_work_PATH/cut_intfs/$intf \
	    #     `gmt grdinfo -I- ${szpddm_file::-4}-cut.grd` -V
	    

	    corrected_phase_file="$GACOS_output_PATH/${slave_date}-${master_date}-intf.grd"
	    gmt grdmath ${szpddm_file::-4}-cut.grd $GACOS_work_PATH/cut_intfs/$intf SUB = $corrected_phase_file -V

	    # Step 4: Linear detrending (?)
	done
    fi
    

    # Module actions end here
    ###########################



    # Stop runtime timer and print runtime
    gacos_end=`date +%s`    
    gacos_runtime=$((gacos_end-gacos_start))

    echo
    printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n\n' \
	$(($gacos_runtime/86400)) \
	$(($gacos_runtime%86400/3600)) \
	$(($gacos_runtime%3600/60)) \
	$(($gacos_runtime%60))
    echo
fi
