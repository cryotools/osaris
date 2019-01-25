#!/usr/bin/env bash

######################################################################
#
# OSARIS module to create a summary of processing results in PDF format.
#
# Provide a valid config file named 'summary_pdf.config' in the config
# directory; a template is provided in templates/module_config/
#
# Input: OSARIS processing results
# Output: PDF summary report
#
# David Loibl, 2018
#
#####################################################################

module_name="summary_pdf"

if [ -z $module_config_PATH ]; then
    echo "Parameter module_config_PATH not set in main config file. Setting to default:"
    echo "  $OSARIS_PATH/config"
    module_config_PATH="$OSARIS_PATH/config"
elif [[ "$module_config_PATH" != /* ]] && [[ "$module_config_PATH" != "$OSARIS_PATH"* ]]; then
    module_config_PATH="${OSARIS_PATH}/config/${module_config_PATH}"    
fi

if [ ! -d "$module_config_PATH" ]; then
    echo "ERROR: $module_config_PATH is not a valid directory. Check parameter module_config_PATH in main config file. Exiting ..."
    exit 2
fi

if [ ! -f "${module_config_PATH}/${module_name}.config" ]; then
    echo
    echo "Cannot open ${module_name}.config in ${module_config_PATH}. Please provide a valid config file."
    echo
else
    CPDFS_start_time=`date +%s`

    source ${module_config_PATH}/${module_name}.config

    echo; echo "Creating the PDF summary ..."


    # Set general params
    pairs_forward=($( cat $work_PATH/pairs-forward.list ))

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

    
    
    # Convert dataset configuration to arrays
    LABELS=( "$LABEL_1" "$LABEL_2" "$LABEL_3" "$LABEL_4" )
    DIRECTORIES=( "$DIRECTORY_1" "$DIRECTORY_2" "$DIRECTORY_3" "$DIRECTORY_4" )
    HISTEQS=( "$HIST_EQ_1" "$HIST_EQ_2" "$HIST_EQ_3" "$HIST_EQ_4" )
    CPTS=( $CPT_1 $CPT_2 $CPT_3 $CPT_4 )
    RANGES=( $RANGE_1 $RANGE_2 $RANGE_3 $RANGE_4 )
    SHOW_SUPPLS=( $SHOW_SUPPL_1 $SHOW_SUPPL_2 $SHOW_SUPPL_3 $SHOW_SUPPL_4 )


    # Set GMT parameters
    gmt gmtset MAP_FRAME_PEN          3
    gmt gmtset MAP_FRAME_WIDTH        0.1
    gmt gmtset MAP_FRAME_TYPE         plain
    gmt gmtset FONT_TITLE             Helvetica-Bold
    gmt gmtset FONT_LABEL             Helvetica-Bold 14p
    gmt gmtset PS_PAGE_ORIENTATION    landscape
    gmt gmtset PS_MEDIA               A4
    gmt gmtset FORMAT_GEO_MAP         D
    gmt gmtset MAP_DEGREE_SYMBOL      degree
    gmt gmtset PROJ_LENGTH_UNIT       cm

        
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
    if [ -z $AOI_REGION ]; then
	# Check for maximum and minimum longitudes and latitudes
	if [ $( echo "$lon_1 < $lon_2" | bc -l ) -eq 1 ]; then
	    lon_max=$lon_2
	    lon_min=$lon_1
	else
	    lon_max=$lon_1
	    lon_min=$lon_2
	fi

	if [ $( echo "$lat_1 < $lat_2" | bc -l ) -eq 1 ]; then
	    lat_max=$lat_2
	    lat_min=$lat_1
	else
	    lat_max=$lat_1
	    lat_min=$lat_2
	fi	
	AOI_REGION="$lon_min/$lon_max/$lat_min/$lat_max"
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
    gmt grdcut $overview_dem -G$CPDFS_dem -R$AOI_REGION -V
    
    # Generate hillshade - will only need to be done once
    if [ ! -f $CPDFS_dem_HS ]; then
    	echo; echo "Generating hillshade $CPDFS_dem_HS"
    	#gmt grdgradient $CPDFS_dem -Ep -Nt1 -G$CPDFS_dem_HS
    	gmt grdgradient $CPDFS_dem -A315/45 -Nt0.6 -G$CPDFS_dem_HS -V
    fi

    
    # Prepare GMT CPTs

    dem_min=$( gmt grdinfo $OVERVIEW_DEM2 | grep z_min | awk '{ print $3 }' )
    dem_max=$( gmt grdinfo $OVERVIEW_DEM2 | grep z_min | awk '{ print $5 }' )   
    echo "DEM min: $dem_min"
    echo "DEM max: $dem_max"
    dem_cpt_config=$( $OSARIS_PATH/lib/steps_boundaries.sh $dem_min $dem_max )
    echo "DEM cpt config: $dem_cpt_config"
    
    if [ -z $dem_cpt ] || [ "$dem_cpt" == "auto" ]; then dem_cpt="#376a4e,#fae394,#8a5117,#7c7772,#ffffff"; fi
    gmt makecpt -C$dem_cpt -T$dem_cpt_config -V > $work_PATH/Summary/dem2_color.cpt # $dem_lower_boundary/$dem_upper_boundary/$dem_step
    gmt makecpt -C$dem_cpt -T$dem_cpt_config -V > $work_PATH/Summary/dem2_overview_color.cpt


    echo; echo "Preparing CPTs for result datasets ..."; echo
    
    for counter in 0 1 2 3; do	
	echo "counter:   $counter"
	echo "RANGE:     ${RANGES[$counter]}"
	echo "DIRECTORY: ${DIRECTORIES[$counter]}"
	echo "LABEL:     ${LABELS[$counter]}"
	echo "CPT:       ${CPTS[$counter]}"
	if [ "${RANGES[$counter]}" == "auto" ] || [ -z ${RANGES[$counter]} ]; then	    
    	    extremes=$( $OSARIS_PATH/lib/z_min_max.sh ${DIRECTORIES[$counter]} )
	    echo "extremes: $extremes"
    	    min_value=$( echo "$extremes" | awk '{ print $1 }' )
    	    max_value=$( echo "$extremes" | awk '{ print $2 }' )    
    	    RANGES[$counter]=$( $OSARIS_PATH/lib/steps_boundaries.sh $min_value $max_value )
	fi
	echo "${LABELS[$counter]} CPT range set to: ${RANGES[$counter]}"

	if [ -z ${CPTS[$counter]} ]; then 
	    CPTS[$counter]="gray"
	    echo "CPT for ${LABELS[$counter]} was not defined. Set to default (gray)."
	fi
	
	CPT_FILES[$counter]="$work_PATH/Summary/grd_${counter}_color.cpt"
	gmt makecpt -C${CPTS[$counter]} -T${RANGES[$counter]} -V > ${CPT_FILES[$counter]}
    done


   

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
	    gmt psxy $vector_style -JM$SCALE -R$AOI_REGION ${!vector_file::-4}.gmt -O -K -V >> $POSTSCRIPT1
	done
    	gmt psscale -R$OVERVIEW_REGION -JM$OVERVIEW_SCALE \
	    -DjBC+o0/-1.5c+w6.5c/0.5c+h -C$CPT -I -F+gwhite+r1p+pthin,black -B1000:Elevation:/:m: -O -K -P -V >> $POSTSCRIPT1
    	convert -quality 100 -density $resolution $POSTSCRIPT1 $output_PATH/Summary/overview-map.pdf 
    else
	echo "Skipping Overview Map Processing ..."
    fi

    echo; echo "Cutting DEM to region of interest"
    gmt grdcut $overview_dem -G$CPDFS_dem -R$AOI_REGION -V
    gmt grdcut $OVERVIEW_DEM2_HS -G$CPDFS_dem_HS -R$AOI_REGION -V



    # Create and merge date maps for each scene pair

    cd $output_PATH

    CPDFS_count=0
    
    echo; echo "Processing files for:"
    echo "${pairs_forward[@]}"
    for intf_pair in "${pairs_forward[@]}"; do           
	
	master_date=${intf_pair:0:8}
	slave_date=${intf_pair:10:8}
	printf "\n \n Now working on results for \n Master date: $master_date \n Slave date: $slave_date \n \n"

	PS_BASE="$work_PATH/Summary/${master_date}-${slave_date}-grd"	
	HISTEQ_BASE="$work_PATH/Summary/${master_date}-${slave_date}-hiq"
	PDF_MERGED="$work_PATH/Summary/${master_date}-${slave_date}-combined.pdf"
	PDF_MERGED_ROT90=${PDF_MERGED::-4}_rot90.png
	
	if [ ! -f "$PDF_MERGED_ROT90" ]; then

	    GRD_FAIL=( 0 0 0 0 )

	    for counter in 0 1 2 3; do 
		echo "Preparing ${LABELS[$counter]} ..."
		# echo "${DIRECTORIES[$counter]}"
		cd ${DIRECTORIES[$counter]}
		ls_result=$( ls ${intf_pair}*.grd )
		if [ -f $ls_result ]; then		    	    
		    GRD[$counter]="${DIRECTORIES[$counter]}/$ls_result"
		    echo "${LABELS[$counter]} file found: ${GRD[$counter]}"		
		    
		    echo "HISTEQS $counter : ${HISTEQS[$counter]}"

		    if [ ${HISTEQS[$counter]} -eq "1" ]; then
			if [ ! -f ${HISTEQ_BASE}-$counter.grd ]; then
    			    echo; echo "Calculate histogram equalization for ${GRD[$counter]}"
    			    gmt grdhisteq ${GRD[$counter]} -G${HISTEQ_BASE}-$counter.grd -N -V
    			    gmt grd2cpt -E15 ${HISTEQ_BASE}-$counter.grd -C${CPTS[$counter]} -V > $work_PATH/Summary/grd_${counter}.cpt
			else
			    echo; echo "${LABELS[$counter]} histogram exists, skipping ..."; echo
			fi
		    fi
		else
		    echo "No ${LABELS[$counter]} file found"
		    GRD_FAIL[$counter]=1
		    GRD_MESSAGE[$counter]="No ${LABELS[$counter]} file"
		fi
	    done


	    
	    cd $work_PATH/Summary

	    SCALE=18  
	    XSTEPS=0.5
	    YSTEPS=0.5	

	    if [ ! -e $PDF_MERGED ]; then
		for counter in 0 1 2 3; do
    		    if [ ! -e ${PS_BASE}-$counter.ps ]; then
			echo; echo "Creating ${LABELS[$counter]} in ${PS_BASE}-$counter.ps"		
			TITLE="${LABELS[$counter]} {master_date}"			
			if [ ! "${GRD_FAIL[$counter]}" -eq 1 ]; then
			    if [ ${HISTEQS[$counter]} -eq 1 ]; then
				echo; echo "${LABELS[$counter]}: ${HISTEQ_BASE}-$counter.grd"; echo
				gmt grdimage ${HISTEQ_BASE}-$counter.grd  \
				    -C$work_PATH/Summary/grd_${counter}.cpt -R$AOI_REGION -JM$SCALE -B+t"$TITLE" -Q \
				    -Bx$XSTEPS -By$YSTEPS -V -K -Yc -Xc > ${PS_BASE}-$counter.ps
			    else
				gmt grdimage ${GRD[$counter]}  \
				    -C${CPT_FILES[$counter]} -R$AOI_REGION -JM$SCALE -B+t"$TITLE" -Q \
				    -Bx$XSTEPS -By$YSTEPS -V -K -Yc -Xc > ${PS_BASE}-$counter.ps
			    fi
			    
			    if [ ${SHOW_SUPPLS[$counter]} -eq 1 ]; then
				for vector_file in ${vector_files[@]}; do
				    style_name=${vector_file}_style
				    vector_style=$( echo "${!style_name}" | tr -d "'" )
				    gmt psxy $vector_style -JM$SCALE -R$AOI_REGION ${!vector_file::-4}.gmt -O -K -V >> ${PS_BASE}-$counter.ps			    				
				done
			    fi
			else			
			    gmt grdimage $CPDFS_dem_HS -C#ffffff,#eeeeee \
				-R$AOI_REGION -JM$SCALE -B+t"${GRD_MESSAGE[$counter]}" -Q -Bx$XSTEPS -By$YSTEPS -V -K -Yc -Xc > ${PS_BASE}-$counter.ps
			    			    
			    
			    if [ $page_orientation -eq 1 ]; then
				convert -density $resolution -fill red -pointsize 18 -gravity center \
				    -trim -verbose label:"${GRD_MESSAGE[$counter]}" \
				    ${PS_BASE}-$counter.ps -quality 100  ${PS_BASE}-$counter.ps
			    else
				convert -rotate 90 -density $resolution -fill red -pointsize 18 -gravity center \
				    -trim -verbose label:"${GRD_MESSAGE[$counter]}" \
				    ${PS_BASE}-$counter.ps -quality 100  ${PS_BASE}-$counter.ps
			    fi
			fi
		    
			if [ $page_orientation -eq 1 ]; then
			    convert -verbose -density $resolution -trim  ${PS_BASE}-$counter.ps -quality 100 ${PS_BASE}-$counter.png
			else
			    convert -verbose -rotate 90 -density $resolution -trim  ${PS_BASE}-$counter.ps -quality 100 ${PS_BASE}-$counter.png
			fi
		    else
			echo; echo "${LABELS[$counter]} in ${PS_BASE}-$counter.ps exists, skipping ..."
    		    fi
		done

		
    		echo "Merging PS into $PDF_MERGED_ROT90"
		take_diff=$(( ($(date --date="$slave_date" +%s) - $(date --date="$master_date" +%s) )/(60*60*24) ))
		if [ "$page_orientation" -eq 1 ]; then
    		    montage ${PS_BASE}-0.png ${PS_BASE}-1.png ${PS_BASE}-2.png ${PS_BASE}-3.png  \
			-rotate 90 -geometry +100+150 -density $resolution -title "${master_date}-${slave_date} (${take_diff} days)" \
			-quality 100 -tile 4x1 -mode concatenate -verbose $PDF_MERGED_ROT90
		else
		    montage -tile 1x4 -geometry +20+30 \
			${PS_BASE}-0.png ${PS_BASE}-1.png ${PS_BASE}-2.png ${PS_BASE}-3.png  \
			-title "${master_date}-${slave_date} (${take_diff} days)" \
			-density $resolution -quality 100 -mode concatenate -verbose $PDF_MERGED_ROT90
		fi


		if [ "$clean_up" -ge 1 ]; then
    		    rm ${PS_BASE}_*.ps 
		    rm ${PS_BASE}_*.png
		fi
		
		if [ "${HISTEQ_BASE}-$counter.grd" != "$CPDFS_dem_HS" ]; then
		    rm ${HISTEQ_BASE}-*.grd
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



