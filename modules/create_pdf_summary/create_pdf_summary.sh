#!/usr/bin/env bash

######################################################################
#
# OSARIS module to create a summary of processing results in PDF format.
#
# Provide a valid config file named 'create_pdf_summary.config' in the config
# directory; a template is provided in templates/module_config/
#
# Input: OSARIS processing results
# Output: PDF summary report
#
# David Loibl, 2018
#
#####################################################################


if [ ! -f "$OSARIS_PATH/config/create_pdf_summary.config" ]; then
    echo
    echo "Cannot open create_pdf_summary.config in the OSARIS config folder. Please provide a valid config file."
    echo
else
    CPDFS_start_time=`date +%s`

    source $OSARIS_PATH/config/create_pdf_summary.config   

    echo; echo "Creating the PDF summary ..."


    # Set general params
    if [ -z $resolution ]; then resolution=300; fi

    # Set pathes and files

    mkdir -p $work_PATH/Summary $output_PATH/Summary    

    dem_grd="$topo_PATH/dem.grd"
    
    if [ -z $overview_dem ]; then
	"No overview DEM spcified in config file. Using dem.grd from $topo_PATH ..."
	overview_dem=$dem_grd;
    elif [ ! -f $overview_dem ]; then
	"$overview_dem is not a valid overview DEM file. Using dem.grd from $topo_PATH ..."
	overview_dem=$dem_grd;
    fi
        
    dem_grd_hs="$work_PATH/Summary/hillshade.grd"
    overview_dem_hs="$work_PATH/Summary/overview_hillshade.grd"

    OVERVIEW_DEM2="$work_PATH/Summary/overview_clip.grd"
    OVERVIEW_DEM2_HS="$work_PATH/Summary/overview_clip_HS.grd"
    DEM_GRD2="$work_PATH/Summary/dem_clip.grd"
    DEM_GRD2_HS="$work_PATH/Summary/dem_clip_HS.grd"
    CPDFS_dem="$work_PATH/Summary/CPDFS_dem.grd"
    CPDFS_dem_HS="$work_PATH/Summary/CPDFS_dem_HS.grd"


    # Set GMT parameters

    gmt gmtset MAP_FRAME_PEN    3
    gmt gmtset MAP_FRAME_WIDTH    0.1
    gmt gmtset MAP_FRAME_TYPE     plain
    gmt gmtset FONT_TITLE    Helvetica-Bold
    gmt gmtset FONT_LABEL    Helvetica-Bold 14p
    gmt gmtset PS_PAGE_ORIENTATION    landscape
    gmt gmtset PS_MEDIA    A4
    gmt gmtset FORMAT_GEO_MAP    D
    gmt gmtset MAP_DEGREE_SYMBOL degree
    gmt gmtset PROJ_LENGTH_UNIT cm

        
    # Check auxilliary vector files and do conversion where neccessary

    vector_files_raw=( reference_polygon aux_polygon_1 aux_polygon_2 aux_line_1 aux_line_2 aux_point_1 aux_point_2 )
    vf_counter=0
    for vector_file in ${vector_files_raw[@]}; do
	if [ -f ${!vector_file} ]; then
	    if [ ${!vector_file: -3} == "shp" ] || [ ${!vector_file: -3} == "SHP" ]; then
    		echo "Converting ${!vector_file} to GMT file"
    		ogr2ogr -f GMT ${!vector_file::-4}.gmt ${!vector_file::-4}.shp
	    fi
	    
	    echo "Vector style: ${vector_file}_style"
	    if [ -z "${vector_file}_style" ]; then
		echo "No style defined for ${vector_file}. Setting to default."
		declare "${vector_file}_style='-Wthinnest,black -Glightblue'"
	    fi
	    vector_files[$vf_counter]=$vector_file
	fi
	((vf_counter++))
    done


    # Initial setting of the region extent

    cd $output_PATH/Pairs-forward

    folders=($( ls -d */ ))
    for folder in "${folders[@]}"; do
    	folder=${folder::-1}
    	if [ -f "$folder/display_amp_ll.grd" ]; then
    	    amp_file_folder=$folder
    	    break
    	fi
    done    

    if [ ! -f "$output_PATH/Pairs-forward/$amp_file_folder/display_amp_ll.grd" ]; then
    	echo; echo "WARNING: No Amplitude file found in all output folders."; echo
    else
    	echo; echo "REGION is set to extent of $output_PATH/Pairs-forward/$amp_file_folder/display_amp_ll.grd"
    	REGION="$output_PATH/Pairs-forward/$amp_file_folder/display_amp_ll.grd"
    fi    


    # Prepare DEMs

    cd $work_PATH/Summary

    POSTSCRIPT1=$work_PATH/Summary/topomap.ps

    if [ ! -e $OVERVIEW_DEM2 ]; then
	echo "Cutting DEM to overview region "
	gmt grdcut $overview_dem -G$OVERVIEW_DEM2 -R$OVERVIEW_REGION -V	    
    fi

    if [ ! -e $OVERVIEW_DEM2_HS ]; then
	echo "Generating hillshade $OVERVIEW_DEM2_HS"
	#gmt grdgradient $CPDFS_dem -Ep -Nt1 -G$CPDFS_dem_HS
	gmt grdgradient $OVERVIEW_DEM2 -A315/45 -Nt0.6 -G$OVERVIEW_DEM2_HS -V
    fi


    echo; echo "Cutting DEM to region of interest"
    gmt grdcut $overview_dem -G$CPDFS_dem -R$REGION -V
    
    #generate hillshade - will only need to be done once
    if [ ! -f $CPDFS_dem_HS ]; then
    	echo; echo "Generating hillshade $CPDFS_dem_HS"
    	#gmt grdgradient $CPDFS_dem -Ep -Nt1 -G$CPDFS_dem_HS
    	gmt grdgradient $CPDFS_dem -A315/45 -Nt0.6 -G$CPDFS_dem_HS -V
    fi

    
    # Prepare min/max/step configurations for GMT CPTs

    dem_min=$( gmt grdinfo $OVERVIEW_DEM2 | grep z_min | awk '{ print $3 }' )
    dem_max=$( gmt grdinfo $OVERVIEW_DEM2 | grep z_min | awk '{ print $5 }' )   
    dem_cpt_config=$( $OSARIS_PATH/lib/steps_boundaries.sh $dem_min $dem_max )
    echo "DEM cpt config: $dem_cpt_config"

    if [ -z $amp_range ]; then
	amp_extremes="$( $OSARIS_PATH/lib/z_min_max.sh $output_PATH/Pairs-forward display_amp_ll.grd $swath )"
	amp_min=$( echo "$amp_extremes" | awk '{ print $1 }' )
	amp_max=$( echo "$amp_extremes" | awk '{ print $2 }' )    
	amp_cpt_config=$( $OSARIS_PATH/lib/steps_boundaries.sh $amp_min $amp_max )
    else
	amp_cpt_config=$amp_range
    fi
    echo "AMP cpt config: $amp_cpt_config"

    # if [ -z $amp_diff_range ]; then
    # 	amp_diff_extremes="$( $OSARIS_PATH/lib/z_min_max.sh $output_PATH/Grid-difference )"
    # 	amp_diff_min=$( echo "$amp_diff_extremes" | awk '{ print $1 }' )
    # 	amp_diff_max=$( echo "$amp_diff_extremes" | awk '{ print $2 }' )    
    # 	amp_diff_cpt_config=$( $OSARIS_PATH/lib/steps_boundaries.sh $amp_diff_min $amp_diff_max 1 )
    # else
    # 	amp_diff_cpt_config=$amp_diff_range
    # fi
    # echo "AMP diff cpt config: $amp_diff_cpt_config"


    # if [ -z $unw_range ]; then
    # 	unw_extremes="$( $OSARIS_PATH/lib/z_min_max.sh unwrap_mask_ll.grd $output_PATH/Pairs-forward $swath )"
    # 	unw_min=$( echo "$unw_extremes" | awk '{ print $1 }' )
    # 	unw_max=$( echo "$unw_extremes" | awk '{ print $2 }' )    
    # 	unw_cpt_config=$( $OSARIS_PATH/lib/steps_boundaries.sh $unw_min $unw_max 1 )
    # else
    # 	unw_cpt_config=$unw_range
    # fi
    # echo "UNW cpt config: $unw_cpt_config"

    if [ -z $ccp_range ]; then
	ccp_extremes="$( $OSARIS_PATH/lib/z_min_max.sh $output_PATH/Pairs-forward con_comp_ll.grd $swath )"
	ccp_min=$( echo "$ccp_extremes" | awk '{ print $1 }' )
	ccp_max=$( echo "$ccp_extremes" | awk '{ print $2 }' )    
	ccp_cpt_config=$( $OSARIS_PATH/lib/steps_boundaries.sh $ccp_min $ccp_max 1 )
    else
	ccp_cpt_config=$ccp_range
    fi
    echo "Con. Comp. cpt config: $unw_cpt_config"


    if [ -z $los_range ]; then
	if [ -d "$output_PATH/Homogenized-Intfs" ]; then
	    los_extremes="$( $OSARIS_PATH/lib/z_min_max.sh $output_PATH/Homogenized-Intfs )"
	else
	    los_extremes="$( $OSARIS_PATH/lib/z_min_max.sh $output_PATH/Pairs-forward los_ll.grd $swath )"
	fi
	los_min=$( echo "$los_extremes" | awk '{ print $1 }' )
	los_max=$( echo "$los_extremes" | awk '{ print $2 }' )    
	los_cpt_config=$( $OSARIS_PATH/lib/steps_boundaries.sh $los_min $los_max 1 )
    else
	los_cpt_config=$los_range
    fi
    echo "LOS cpt config: $los_cpt_config"
    
    if [ -z $coh_range ]; then
	coh_cpt_config="0/1/0.1"
    else
	coh_cpt_config=$coh_range
    fi


    # Prepare CPTs

    if [ -z $dem_cpt ]; then dem_cpt="#376a4e,#fae394,#8a5117,#7c7772,#ffffff"; fi
    if [ -z $amp_cpt ]; then amp_cpt="gray"; fi
    if [ -z $coh_cpt ]; then coh_cpt="jet"; fi
    # if [ -z $unw_cpt ]; then unw_cpt="seis"; fi
    if [ -z $ccp_cpt ]; then ccp_cpt="gray"; fi
    if [ -z $los_cpt ]; then los_cpt="cyclic"; fi

    # Make color tables - only one is needed
    # gmt makecpt -Cwysiwyg -T0/5/1 > conncomp_color.cpt
    gmt makecpt -C$coh_cpt -T$coh_cpt_config -V > $work_PATH/Summary/coherence_color.cpt
    gmt makecpt -C$los_cpt -T$los_cpt_config -V > $work_PATH/Summary/LOS_color.cpt # $LOS_MIN/$LOS_MAX/$LOS_STEP
    # gmt makecpt -C$unw_cpt -T$unw_cpt_config -V > $work_PATH/Summary/unw_color.cpt
    gmt makecpt -C$ccp_cpt -T$ccp_cpt_config -V > $work_PATH/Summary/ccp_color.cpt
    gmt makecpt -C$amp_cpt -T$amp_cpt_config > amp_grayscale.cpt
    gmt makecpt -C$dem_cpt -T$dem_cpt_config -V > $work_PATH/Summary/dem2_color.cpt # $dem_lower_boundary/$dem_upper_boundary/$dem_step
    gmt makecpt -C$dem_cpt -T$dem_cpt_config -V > $work_PATH/Summary/dem2_overview_color.cpt


    # Create overview map

    if [ ! -e $POSTSCRIPT1 ]; then
	echo; printf "Creating overviewmap in \n ${POSTSCRIPT1} \n \n"
	
    	OVERVIEW_SCALE=12
    	OVERVIEW_XSTEPS=1
    	OVERVIEW_YSTEPS=1
    	TITLE="Overview map"
    	CPT="$work_PATH/Summary/dem2_overview_color.cpt"
    	gmt grdimage $OVERVIEW_DEM2 -I$OVERVIEW_DEM2_HS \
	    -C$CPT -R$OVERVIEW_REGION -JM$OVERVIEW_SCALE -B+t"$TITLE" \
	    -Xc -Yc -Bx$OVERVIEW_XSTEPS -By$OVERVIEW_YSTEPS -V -K -P > $POSTSCRIPT1

	for vector_file in ${vector_files[@]}; do
	    style_name=${vector_file}_style
	    vector_style=$( echo "${!style_name}" | tr -d "'" )
	    gmt psxy $vector_style -JM$SCALE -R$REGION ${!vector_file::-4}.gmt -O -K -V >> $POSTSCRIPT1
	done
    	gmt psscale -R$OVERVIEW_REGION -JM$OVERVIEW_SCALE \
	    -DjBC+o0/-1.5c+w6.5c/0.5c+h -C$CPT -I -F+gwhite+r1p+pthin,black -B1000:Elevation:/:m: -O -K -P -V >> $POSTSCRIPT1
    	convert -quality 100 -density $resolution $POSTSCRIPT1 $output_PATH/Summary/overview-map.pdf 
    else
	echo "Skipping Overview Map Processing ..."
    fi


    # Create and merge date maps for each scene pair

    cd $output_PATH/Pairs-forward

    folders=($( ls -d */ ))
    CPDFS_count=0
    for folder in "${folders[@]}"; do           
	folder=${folder::-1}
	master_date=${folder:0:8}
	slave_date=${folder:10:8}
	printf "\n Master date: $master_date \n Slave date: $slave_date \n \n"


	POSTSCRIPT2=$work_PATH/Summary/${master_date}-${slave_date}-amplitude.ps
	POSTSCRIPT3=$work_PATH/Summary/${master_date}-${slave_date}-coherence.ps
	# POSTSCRIPT4=$work_PATH/Summary/${master_date}-${slave_date}-unwrintf.ps
	POSTSCRIPT4=$work_PATH/Summary/${master_date}-${slave_date}-concomp.ps
	POSTSCRIPT5=$work_PATH/Summary/${master_date}-${slave_date}-los.ps

	PDF_MERGED="$work_PATH/Summary/${master_date}-${slave_date}-combined.pdf"
	PDF_MERGED_ROT90=${PDF_MERGED::-4}_rot90.png
	
	if [ ! -f "$PDF_MERGED_ROT90" ]; then

	    amp_fail=0
	    coh_fail=0
	    # unw_fail=0
	    ccp_fail=0
	    los_fail=0
	    	    

	    echo "Now looking for amp ..."
	    if [ -f "$output_PATH/Pairs-forward/$folder/display_amp_ll.grd" ]; then
		echo "Amplitude file found: $output_PATH/Pairs-forward/$folder/display_amp_ll.grd"
		AMPLITUDE_GRD="$output_PATH/Pairs-forward/$folder/display_amp_ll.grd"
		REGION=$AMPLITUDE_GRD
		echo; echo "Cutting DEM to region of interest"
    		gmt grdcut $overview_dem -G$CPDFS_dem -R$REGION -V
		gmt grdcut $OVERVIEW_DEM2_HS -G$CPDFS_dem_HS -R$REGION -V
	    
		AMPLITUDE_GRD_HISTEQ="$work_PATH/Summary/amp_histeq.grd"

		if [ ! -f $AMPLITUDE_GRD_HISTEQ ]; then
    		    echo; echo "Calculate histogram equalization for ${AMPLITUDE_GRD}"
    		    gmt grdhisteq $AMPLITUDE_GRD -G$AMPLITUDE_GRD_HISTEQ -N -V
    		    gmt grd2cpt -E15 $AMPLITUDE_GRD_HISTEQ -Cgray -V > $work_PATH/Summary/amp_grayscale.cpt
		else
		    echo; echo "Amplitude histogram exists, skipping ..."; echo
		fi

	    else
		echo "No amplitude file found"
		# AMPLITUDE_GRD=$CPDFS_dem_HS
		# AMPLITUDE_GRD_HISTEQ=$CPDFS_dem_HS
		amp_fail=1
		amp_message="No amplitude file"
	    fi

	    echo "Now looking for coh ..."
	    if [ -f "$output_PATH/Pairs-forward/$folder/corr_ll.grd" ]; then
		echo "Coherence file found: $output_PATH/Pairs-forward/$folder/corr_ll.grd"
		COHERENCE_PHASE_GRD="$output_PATH/Pairs-forward/$folder/corr_ll.grd"
	    else
		echo "No coherence file found."
		# COHERENCE_PHASE_GRD=$CPDFS_dem_HS
		coh_fail=1
		coh_message="No coherence file"
	    fi
	    
	    # echo "Now looking for unw ..."
	    # if [ -f "$output_PATH/homogenized_intfs/${folder}-hintf.grd" ]; then
	    # 	echo "Homog. Unw. Intf file found: $output_PATH/homogenized_intfs/${folder}-hintf.grd"
	    # 	UNWSNAPHU_GRD="$output_PATH/homogenized_intfs/${folder}-hintf.grd"   
	    # elif [ -f "$output_PATH/Pairs-forward/$folder/unwrap_mask_ll.grd" ]; then
	    # 	echo "Using raw unw. intf: $output_PATH/Pairs-forward/$folder/unwrap_mask_ll.grd"
	    # 	UNWSNAPHU_GRD="$output_PATH/Pairs-forward/$folder/unwrap_mask_ll.grd"
	    # else
	    # 	echo "No unwr. intf. file found"
	    # 	# UNWSNAPHU_GRD=$CPDFS_dem_HS
	    # 	unw_fail=1
	    # 	unw_message="No unwr. interferogram"
	    # fi
	    
	    echo "Now looking for connected components ..."
	    if [ -f "$output_PATH/Pairs-forward/$folder/con_comp_ll.grd" ]; then
		echo "Connected Components file found: $output_PATH/Pairs-forward/$folder/con_comp_ll.grd"
		CONCOMP_GRD="$output_PATH/Pairs-forward/$folder/con_comp_ll.grd"
	    else
		echo "No con. components file found"
		ccp_fail=1
		ccp_message="No con. components file"
	    fi


	    echo "Now looking for los ..."
	    if [ -f "$output_PATH/homogenized_intfs/${folder}-hlosdsp.grd" ]; then
		echo "Homog. LOS file found at $output_PATH/homogenized_intfs/${folder}-hlosdsp.grd"
		LOS_GRD="$output_PATH/homogenized_intfs/${folder}-hlosdsp.grd"		    
	    elif [ -f "$output_PATH/Pairs-forward/$folder/los_ll.grd" ]; then
		echo "Using raw LOS file from $output_PATH/Pairs-forward/$folder/los_ll.grd"
		LOS_GRD="$output_PATH/Pairs-forward/$folder/los_ll.grd"
	    else
		echo "No LOS file found."
		# LOS_GRD=$CPDFS_dem
		los_fail=1
		los_message="No LOS file"
	    fi

	    
	    cd $work_PATH/Summary

	    SCALE=18  
	    XSTEPS=0.5
	    YSTEPS=0.5	

	    if [ ! -e $PDF_MERGED ]; then
    		if [ ! -e $POSTSCRIPT2 ]; then
		    echo; echo "Creating Amplitude in ${POSTSCRIPT2}"		
		    TITLE="Amplitude {master_date}"
		    echo; echo "Amplitude: $AMPLITUDE_GRD_HISTEQ"; echo
		    if [ ! "$amp_fail" -eq 1 ]; then
			CPT="$work_PATH/Summary/amp_grayscale.cpt"
			gmt grdimage $AMPLITUDE_GRD_HISTEQ  \
			    -C$CPT -R$REGION -JM$SCALE -B+t"$TITLE" -Q -Bx$XSTEPS -By$YSTEPS -V -K -Yc -Xc > $POSTSCRIPT2
			for vector_file in ${vector_files[@]}; do
			    style_name=${vector_file}_style
			    vector_style=$( echo "${!style_name}" | tr -d "'" )
			    gmt psxy $vector_style -JM$SCALE -R$REGION ${!vector_file::-4}.gmt -O -K -V >> $POSTSCRIPT2			    
			    # echo; echo "${!style_name}"; echo "gmt psxy $vector_style -JM$SCALE -R$REGION ${!vector_file::-4}.gmt -O -K >> $POSTSCRIPT2"
			done
		    else			
			gmt grdimage $CPDFS_dem_HS -C#ffffff,#eeeeee \
			    -R$REGION -JM$SCALE -B+t"$amp_message" -Q -Bx$XSTEPS -By$YSTEPS -V -K -Yc -Xc > $POSTSCRIPT2
			# echo $amp_message | gmt pstext -F+f12p,Helvetica-Bold,red -R$REGION -JM$SCALE  >> $POSTSCRIPT2
			
			
			if [ $page_orientation -eq 1 ]; then
			    convert -density $resolution -fill red -pointsize 18 -gravity center -trim -verbose label:"$amp_message" $POSTSCRIPT2 -quality 100  $POSTSCRIPT2
			else
			    convert -rotate 90 -density $resolution -fill red -pointsize 18 -gravity center -trim -verbose label:"$amp_message" $POSTSCRIPT2 -quality 100  $POSTSCRIPT2
			fi

		    fi		    
		    if [ $page_orientation -eq 1 ]; then
			convert -verbose -density $resolution -trim  $POSTSCRIPT2 -quality 100 ${POSTSCRIPT2::-3}.png
		    else
			convert -verbose -rotate 90 -density $resolution -trim  $POSTSCRIPT2 -quality 100 ${POSTSCRIPT2::-3}.png
		    fi
		else
		    echo; echo "Amplitude in ${POSTSCRIPT2} exists, skipping ..."
    		fi

    		if [ ! -e $POSTSCRIPT3 ]; then
		    echo; echo "Creating Coherence in ${POSTSCRIPT3}"
		    TITLE="Coherence ${master_date}-${slave_date}"
		    if [ ! "$coh_fail" -eq 1 ]; then
			CPT="$work_PATH/Summary/coherence_color.cpt"
			gmt grdimage $COHERENCE_PHASE_GRD \
			    -C$CPT -R$REGION -JM$SCALE -B+t"$TITLE" -Q -Bx$XSTEPS -By$YSTEPS -V -K -Yc -Xc > $POSTSCRIPT3			
			gmt psscale -R$REGION -JM$SCALE -DjBC+o0/-1.5c+w6.5c/0.5c+h \
			    -C$CPT -I -F+gwhite+r1p+pthin,black -B0.2 -O -K -V >> $POSTSCRIPT3
		    else
			gmt grdimage $CPDFS_dem_HS -C#ffffff,#eeeeee \
			    -R$REGION -JM$SCALE -B+t"$coh_message" -Q -Bx$XSTEPS -By$YSTEPS -V -K -Yc -Xc > $POSTSCRIPT3
		    fi
		    
		    if [ $page_orientation -eq 1 ]; then
			convert -verbose -density $resolution -trim  $POSTSCRIPT3 -quality 100 ${POSTSCRIPT3::-3}.png
		    else
			convert -verbose -rotate 90 -density $resolution -trim  $POSTSCRIPT3 -quality 100 ${POSTSCRIPT3::-3}.png
		    fi

		else
		    echo; echo "Coherence in ${POSTSCRIPT3} exists, skipping ..."
    		fi

    		# if [ ! -e $POSTSCRIPT4 ]; then
	    	#     echo; echo "Creating Unwrapped Phase in ${POSTSCRIPT4}"
	    	#     TITLE="Unwrapped Phase (mm/yr)"
		#     if [ ! "$unw_fail" -eq 1 ]; then
	    	# 	CPT="$work_PATH/Summary/unw_color.cpt"
	    	# 	gmt grdimage $UNWSNAPHU_GRD -C$CPT -R$REGION -JM$SCALE -B+t"$TITLE" -Q -Bx$XSTEPS -By$YSTEPS -V -K -Yc -Xc > $POSTSCRIPT4
		# 	gmt psscale -R$REGION -JM$SCALE -DjBC+o0/-1.5c+w6.5c/0.5c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Baf -O -K -V >> $POSTSCRIPT4    # 
		#     else
		# 	gmt grdimage $CPDFS_dem_HS -C#ffffff,#eeeeee \
		# 	    -R$REGION -JM$SCALE -B+t"$unw_message" -Q -Bx$XSTEPS -By$YSTEPS -V -K -Yc -Xc > $POSTSCRIPT4
		#     fi
		#     convert -verbose -density $resolution -trim  $POSTSCRIPT4 -quality 100 ${POSTSCRIPT4::-3}.png

		# else
		#     echo; echo "Unwrapped phase in ${POSTSCRIPT4} exists, skipping ..."
    		# fi

		if [ ! -e $POSTSCRIPT4 ]; then
	    	    echo; echo "Creating Connected Components in ${POSTSCRIPT4}"
	    	    TITLE="Connected Components"
		    if [ ! "$ccp_fail" -eq 1 ]; then
	    		CPT="$work_PATH/Summary/ccp_color.cpt"
	    		gmt grdimage $CONCOMP_GRD -C$CPT -R$REGION -JM$SCALE -B+t"$TITLE" -Q -Bx$XSTEPS -By$YSTEPS -V -K -Yc -Xc > $POSTSCRIPT4
			#gmt psscale -R$REGION -JM$SCALE -DjBC+o0/-1.5c+w6.5c/0.5c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Baf -O -K -V >> $POSTSCRIPT4    # 
		    else
			gmt grdimage $CPDFS_dem_HS -C#ffffff,#eeeeee \
			    -R$REGION -JM$SCALE -B+t"$ccp_message" -Q -Bx$XSTEPS -By$YSTEPS -V -K -Yc -Xc > $POSTSCRIPT4
		    fi

		    if [ $page_orientation -eq 1 ]; then
			convert -verbose -density $resolution -trim  $POSTSCRIPT4 -quality 100 ${POSTSCRIPT4::-3}.png
		    else
			convert -verbose -rotate 90 -density $resolution -trim  $POSTSCRIPT4 -quality 100 ${POSTSCRIPT4::-3}.png
		    fi

		else
		    echo; echo "Connected components in ${POSTSCRIPT4} exists, skipping ..."
    		fi


    		if [ ! -e $POSTSCRIPT5 ]; then
		    echo; echo "Creating LOS (mm/yr) in ${POSTSCRIPT5}"
		    TITLE="LOS (mm/yr)"
		    if [ ! "$los_fail" -eq 1 ]; then
			CPT="$work_PATH/Summary/LOS_color.cpt"
			gmt grdimage $LOS_GRD -C$CPT -R$REGION -JM$SCALE -B+t"$TITLE" -Q -Bx$XSTEPS -By$YSTEPS -V -K -Yc -Xc > $POSTSCRIPT5			
			gmt psscale -R$REGION -JM$SCALE -DjBC+o0/-1.5c+w6.5c/0.5c+h -C$CPT -I -F+gwhite+r1p+pthin,black -Baf -O -K -V >> $POSTSCRIPT5
		    else
			gmt grdimage $CPDFS_dem_HS -C#ffffff,#eeeeee \
			    -R$REGION -JM$SCALE -B+t"$coh_message" -Q -Bx$XSTEPS -By$YSTEPS -V -K -Yc -Xc > $POSTSCRIPT5
		    fi
		    
		    if [ "$page_orientation" -eq 1 ]; then
			convert -verbose -density $resolution -trim  $POSTSCRIPT5 -quality 100 ${POSTSCRIPT5::-3}.png
		    else
			convert -verbose -rotate 90 -density $resolution -trim  $POSTSCRIPT5 -quality 100 ${POSTSCRIPT5::-3}.png
		    fi
		else
		    echo; echo "LOS in ${POSTSCRIPT5} exists, skipping ..."
    		fi

		
    		echo "Merging PS into $PDF_MERGED_ROT90"
		take_diff=$(( ($(date --date="$slave_date" +%s) - $(date --date="$master_date" +%s) )/(60*60*24) ))
		if [ "$page_orientation" -eq 1 ]; then
    		    montage ${POSTSCRIPT2::-3}.png ${POSTSCRIPT3::-3}.png ${POSTSCRIPT4::-3}.png ${POSTSCRIPT5::-3}.png \
			-rotate 90 -geometry +100+150 -density $resolution -title "${master_date}-${slave_date} (${take_diff} days)" \
			-quality 100 -tile 4x1 -mode concatenate -verbose $PDF_MERGED_ROT90
		else
		    montage -tile 1x4 -geometry +20+30 \
			${POSTSCRIPT2::-3}.png ${POSTSCRIPT3::-3}.png ${POSTSCRIPT4::-3}.png ${POSTSCRIPT5::-3}.png \
			-title "${master_date}-${slave_date} (${take_diff} days)" \
			-density $resolution -quality 100 -mode concatenate -verbose $PDF_MERGED_ROT90
		fi


		if [ "$clean_up" -ge 1 ]; then
    		    rm $POSTSCRIPT2 $POSTSCRIPT3 $POSTSCRIPT4 $POSTSCRIPT5
		    rm ${POSTSCRIPT2::-3}.png ${POSTSCRIPT3::-3}.png ${POSTSCRIPT4::-3}.png ${POSTSCRIPT5::-3}.png
		fi
		
		if [ "$AMPLITUDE_GRD_HISTEQ" != "$CPDFS_dem_HS" ]; then
		    rm $AMPLITUDE_GRD_HISTEQ
		fi
	    fi
	else
	    echo "File $PDF_MERGED_ROT90 exists, skipping ..."
	fi
	    	
	((CPDFS_count+1))
    done
    

    # Merge all rows to PDF summary file

    cd $work_PATH/Summary

    png_tiles=$( ls *rot90.png )
    png_tile_count=$( ls -l *rot90.png | wc -l )
    
    echo; echo "Merging files to $output_PATH/Summary/${prefix}-summary.pdf"
    if [ -z $images_per_page ]; then
	echo "No value set for images_per_page, using default value '5'"
	images_per_page=5
    fi

    if [ $page_orientation -eq 1 ]; then
	montage -page 2480x3508 -density $resolution -units pixelsperinch -compress zip -quality 90 -tile 1x$images_per_page \
	    -mode concatenate -verbose -geometry +50+100 \
	    $png_tiles \
	    "$output_PATH/Summary/Summary-${prefix}.pdf"
    else
	montage -page 3508x2480 -density $resolution -units pixelsperinch -compress zip -quality 90 -tile ${images_per_page}x1 \
	    -mode concatenate -verbose -geometry +50+100 \
	    $png_tiles \
	    "$output_PATH/Summary/Summary-${prefix}.pdf"
    fi


    # Calculate runtime

    CPDFS_end_time=`date +%s`
    CPDFS_runtime=$((CPDFS_end_time - CPDFS_start_time))
    printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n' $(($CPDFS_runtime/86400)) $(($CPDFS_runtime%86400/3600)) $(($CPDFS_runtime%3600/60)) $(($CPDFS_runtime%60))
    echo

fi
