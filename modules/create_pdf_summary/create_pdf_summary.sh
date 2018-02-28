#!/bin/bash

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


    # #Set parameters
    LOS_MIN="-50"
    LOS_MAX="50"
    LOS_STEP="5"


    # Check auxilliary vector files and do conversion where neccessary

    vector_files_raw=( reference_polygon aux_polygon_1 aux_polygon_2 aux_line_1 aux_line_2 aux_point_1 aux_point_2 )
    vf_counter=0
    for vector_file in ${vector_files_raw[@]}; do
	if [ -f ${!vector_file} ]; then
	    if [ ${!vector_file: -3} == "shp" ] || [ ${!vector_file: -3} == "SHP" ]; then
    		echo "Converting ${!vector_file} to GMT file"
    		ogr2ogr -f GMT ${!vector_file::-4}.gmt ${!vector_file::-4}.shp
	    fi
	    
	    echo; echo "Vector style: ${vector_file}_style"
	    if [ -z "${vector_file}_style" ]; then
		echo "No style defined for ${vector_file}. Setting to default."
		declare "${vector_file}_style='-Wthinnest,black -Glightblue'"
	    fi
	    vector_files[$vf_counter]=$vector_file
	fi
	((vf_counter++))
    done
      


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

    dem_min=$( gmt grdinfo $OVERVIEW_DEM2 | grep z_min | awk '{ print $3 }' )
    dem_max=$( gmt grdinfo $OVERVIEW_DEM2 | grep z_min | awk '{ print $5 }' )
    dem_diff=$( echo "$dem_max - $dem_min" | bc )
    if [ $( echo "$dem_diff > 5000" | bc ) -eq 1 ]; then
	dem_step=500
    elif [ $( echo "$dem_diff > 2000" | bc ) -eq 1 ]; then
	dem_step=200
    elif [ $( echo "$dem_diff > 1000" | bc ) -eq 1 ]; then
	dem_step=100
    elif [ $( echo "$dem_diff > 500" | bc ) -eq 1 ]; then
	dem_step=50
    elif [ $( echo "$dem_diff > 200" | bc ) -eq 1 ]; then
	dem_step=20
    else
	dem_step=10
    fi
    dem_min_remainder=$( echo "$dem_min%$dem_step" | bc )
    dem_lower_boundary=$( echo "$dem_min-$dem_min_remainder" | bc )
    dem_max_remainder=$( echo "$dem_max%$dem_step" | bc )
    dem_upper_boundary=$( echo "$dem_max-$dem_max_remainder+$dem_step" | bc )
    
    echo; echo "DEM params: $dem_min/$dem_max/$dem_lower_boundary/$dem_upper_boundary/$dem_step"
    # Make color tables - only one is needed
    # gmt makecpt -Cwysiwyg -T0/5/1 > conncomp_color.cpt
    gmt makecpt -Cjet -T0/1/0.1 -V > $work_PATH/Summary/coherence_color.cpt
    gmt makecpt -Ccyclic -T$LOS_MIN/$LOS_MAX/$LOS_STEP -V > $work_PATH/Summary/LOS_color.cpt
    gmt makecpt -Cgray -T$AMP_MIN/$AMP_MAX/$AMP_STEP > amp_grayscale.cpt
    gmt makecpt -Cdem2 -T$dem_lower_boundary/$dem_upper_boundary/$dem_step -V > $work_PATH/Summary/dem2_color.cpt
    gmt makecpt -C#376a4e,#fae394,#8a5117,#7c7772,#ffffff -T$dem_lower_boundary/$dem_upper_boundary/$dem_step -V > $work_PATH/Summary/dem2_overview_color.cpt


    if [ ! -e $POSTSCRIPT1 ]; then
	echo; printf "Creating overviewmap in \n ${POSTSCRIPT1} \n \n"
	
    	OVERVIEW_SCALE=12
    	OVERVIEW_XSTEPS=1
    	OVERVIEW_YSTEPS=1
    	TITLE="Overview map"
    	CPT="$work_PATH/Summary/dem2_overview_color.cpt"
    	gmt grdimage $OVERVIEW_DEM2 -I$OVERVIEW_DEM2_HS -C$CPT -R$OVERVIEW_REGION -JM$OVERVIEW_SCALE -B+t"$TITLE" -Xc -Yc -Bx$OVERVIEW_XSTEPS -By$OVERVIEW_YSTEPS -V -K -P > $POSTSCRIPT1

	for vector_file in ${vector_files[@]}; do
	    style_name=${vector_file}_style
	    vector_style=$( echo "${!style_name}" | tr -d "'" )
	    gmt psxy $vector_style -JM$SCALE -R$REGION ${!vector_file::-4}.gmt -O -K -V >> $POSTSCRIPT1
	done
    	gmt psscale -R$OVERVIEW_REGION -JM$OVERVIEW_SCALE -DjBC+o0/-1.5c+w6.5c/0.5c+h -C$CPT -I -F+gwhite+r1p+pthin,black -B1000:Elevation:/:m: -O -K -P -V >> $POSTSCRIPT1
    	convert -quality 100 -density 300 $POSTSCRIPT1 $output_PATH/Summary/overview-map.pdf 
    else
	echo "Skipping Overview Map Processing ..."
    fi


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
	POSTSCRIPT4=$work_PATH/Summary/${master_date}-${slave_date}-unwrintf.ps
	POSTSCRIPT5=$work_PATH/Summary/${master_date}-${slave_date}-los.ps

	PDF_MERGED="$work_PATH/Summary/${master_date}-${slave_date}-combined.pdf"
	PDF_MERGED_ROT90=${PDF_MERGED::-4}_rot90.png
	
	if [ ! -f "$PDF_MERGED_ROT90" ]; then
	    AMPLITUDE_GRD="$output_PATH/Pairs-forward/$folder/display_amp_ll.grd"
	    AMPLITUDE_GRD_HISTEQ="$work_PATH/Summary/amp_histeq.grd"
	    COHERENCE_PHASE_GRD="$output_PATH/Pairs-forward/$folder/corr_ll.grd"
	    
	    if [ -d "$output_PATH/homogenized_intfs" ]; then
		UNWSNAPHU_GRD="$output_PATH/homogenized_intfs/hintf_${folder}.grd"
		LOS_GRD="$output_PATH/homogenized_intfs/hlosdsp_${folder}.grd"
	    else
		UNWSNAPHU_GRD="$output_PATH/Pairs-forward/$folder/unwrap_mask_ll.grd"
		LOS_GRD="$output_PATH/Pairs-forward/$folder/los_ll.grd"
	    fi

	    REGION=$AMPLITUDE_GRD

	    if [ ! -f $AMPLITUDE_GRD_HISTEQ ]; then
    		echo; echo "Calculate histogram equalization for ${AMPLITUDE_GRD}"
    		gmt grdhisteq $AMPLITUDE_GRD -G$AMPLITUDE_GRD_HISTEQ -N -V
    		gmt grd2cpt -E15 $AMPLITUDE_GRD_HISTEQ -Cgray -V > $work_PATH/Summary/amp_grayscale.cpt
	    else
		echo; echo "Amplitude histogram exists, skipping ..."; echo
	    fi

	    if [ ! -f $CPDFS_dem ]
	    then
    		echo; echo "Cutting DEM to region of interest"
    		gmt grdcut $overview_dem -G$CPDFS_dem -R$REGION -V
	    fi

	    #generate hillshade - will only need to be done once
	    if [ ! -f $CPDFS_dem_HS ]
	    then
    		echo; echo "Generating hillshade $DEM_GRID_HS"
    		#gmt grdgradient $CPDFS_dem -Ep -Nt1 -G$CPDFS_dem_HS
    		gmt grdgradient $CPDFS_dem -A315/45 -Nt0.6 -G$CPDFS_dem_HS -V
	    fi

	    
	    cd $work_PATH/Summary


	    SCALE=18  
	    XSTEPS=0.5
	    YSTEPS=0.5	

	    if [ ! -e $PDF_MERGED ]; then
    		if [ ! -e $POSTSCRIPT2 ]; then
		    echo; echo "Creating Amplitude in ${POSTSCRIPT2}"		
		    TITLE="Amplitude ${master_date}"
		    if [ -f "$AMPLITUDE_GRD_HISTEQ" ]; then
			CPT="$work_PATH/Summary/amp_grayscale.cpt"
			gmt grdimage $AMPLITUDE_GRD_HISTEQ -I$CPDFS_dem_HS -C$CPT -R$REGION -JM$SCALE -B+t"$TITLE" -Q -Bx$XSTEPS -By$YSTEPS -V -K -Yc -Xc > $POSTSCRIPT2
			for vector_file in ${vector_files[@]}; do
			    style_name=${vector_file}_style
			    vector_style=$( echo "${!style_name}" | tr -d "'" )
			    gmt psxy $vector_style -JM$SCALE -R$REGION ${!vector_file::-4}.gmt -O -K -V >> $POSTSCRIPT2			    
			    # echo; echo "${!style_name}"; echo "gmt psxy $vector_style -JM$SCALE -R$REGION ${!vector_file::-4}.gmt -O -K >> $POSTSCRIPT2"
			done

		    else
			gmt grdimage $CPDFS_dem_HS -C#ffffff,#eeeeee -R$REGION -JM$SCALE -B+t"$TITLE" -Q -V -K -Yc -Xc > $POSTSCRIPT2
		    fi
		else
		    echo; echo "Amplitude in ${POSTSCRIPT2} exists, skipping ..."
    		fi

    		if [ ! -e $POSTSCRIPT3 ]; then
		    echo; echo "Creating Coherence in ${POSTSCRIPT3}"
		    TITLE="Coherence ${master_date}-${slave_date}"
		    if [ -f $COHERENCE_PHASE_GRD ]; then
			CPT="$work_PATH/Summary/coherence_color.cpt"
			gmt grdimage $COHERENCE_PHASE_GRD -I$CPDFS_dem_HS -C$CPT -R$REGION -JM$SCALE -B+t"$TITLE" -Q -Bx$XSTEPS -By$YSTEPS -V -K -Yc -Xc > $POSTSCRIPT3
			gmt psxy -Wthinnest,lightblue -R$REGION -Glightblue -JM$SCALE $aux_polygon_1 -O -K -V >> $POSTSCRIPT3
			gmt psscale -R$REGION -JM$SCALE -DjBC+o0/-1.5c+w6.5c/0.5c+h -C$CPT -I -F+gwhite+r1p+pthin,black -B0.2:"Coherence (0-1)":/:/: -O -K -V >> $POSTSCRIPT3
		    else
			gmt grdimage $CPDFS_dem_HS -C#ffffff,#eeeeee -R$REGION -JM$SCALE -B+t"$TITLE" -Q -V -K -Yc -Xc > $POSTSCRIPT3
		    fi
		else
		    echo; echo "Coherence in ${POSTSCRIPT3} exists, skipping ..."
    		fi

    		if [ ! -e $POSTSCRIPT4 ]; then
	    	    echo; echo "Creating Unwrapped Phase in ${POSTSCRIPT4}"
	    	    TITLE="Unwrapped Phase"
		    if [ -f $UNWSNAPHU_GRD ]; then
	    		CPT="$work_PATH/Summary/LOS_color.cpt"
	    		gmt grdimage $UNWSNAPHU_GRD -I$CPDFS_dem_HS -C$CPT -R$REGION -JM$SCALE -B+t"$TITLE" -Q -Bx$XSTEPS -By$YSTEPS -V -K -Yc -Xc > $POSTSCRIPT4	    	
	    		gmt psxy -Wthinnest,lightblue -R$REGION -Glightblue -JM$SCALE $aux_polygon_1 -O -K >> $POSTSCRIPT4	    	
	    		gmt psxy -Sa0.5c -Wblack -Gwhite -R$REGION -JM$SCALE $reference_polygon -O -K >> $POSTSCRIPT4
		    else
			gmt grdimage $CPDFS_dem_HS -C#ffffff,#eeeeee -R$REGION -JM$SCALE -B+t"$TITLE" -Q -V -K -Yc -Xc > $POSTSCRIPT4
		    fi

		else
		    echo; echo "Unwrapped phase in ${POSTSCRIPT4} exists, skipping ..."
    		fi


    		if [ ! -e $POSTSCRIPT5 ]; then
		    echo; echo "Creating LOS (mm/yr) in ${POSTSCRIPT5}"
		    TITLE="LOS (mm/yr)"
		    if [ -f $LOS_GRD ]; then
			CPT="$work_PATH/Summary/LOS_color.cpt"
			gmt grdimage $LOS_GRD -I$CPDFS_dem_HS -C$CPT -R$REGION -JM$SCALE -B+t"$TITLE" -Q -Bx$XSTEPS -By$YSTEPS -V -K -Yc -Xc > $POSTSCRIPT5
			gmt psxy -Wthinnest,lightblue -R$REGION -Glightblue -JM$SCALE $aux_polygon_1 -O -K -V >> $POSTSCRIPT5
			gmt psxy -Wthinnest,white -R$REGION -JM$SCALE $reference_polygon -O -K -V >> $POSTSCRIPT5
			gmt psscale -R$REGION -JM$SCALE -DjBC+o0/-1.5c+w6.5c/0.5c+h -C$CPT -I -F+gwhite+r1p+pthin,black -B2:"LOS":/:"mm/yr": -O -K -V >> $POSTSCRIPT5
		    else
			gmt grdimage $CPDFS_dem_HS -C#ffffff,#eeeeee -R$REGION -JM$SCALE -B+t"$TITLE" -Q -V -K -Yc -Xc > $POSTSCRIPT5
		    fi
		else
		    echo; echo "LOS in ${POSTSCRIPT5} exists, skipping ..."
    		fi

    		# echo; echo "Merging PS into $PDF_MERGED"				
    		#montage ${POSTSCRIPT2} ${POSTSCRIPT3} ${POSTSCRIPT4} ${POSTSCRIPT5} -resize 2480x3508 -title "Sentinel1: ${master_date}-${slave_date}" -quality 100 -density 300 -tile 2x2 -geometry +50+10 -mode concatenate -extent 2480x3508 -page 2480x3508 ${PDF_MERGED}
    		echo "Merging PS into $PDF_MERGED_ROT90"
    		montage ${POSTSCRIPT2} ${POSTSCRIPT3} ${POSTSCRIPT4} ${POSTSCRIPT5} -rotate 90 -title "${master_date}-${slave_date}" -quality 90 -density 300 -tile 4x1 -geometry +100-500 -mode concatenate -verbose $PDF_MERGED_ROT90
    		# rm $POSTSCRIPT2 $POSTSCRIPT3 $POSTSCRIPT4 $POSTSCRIPT5
		rm $AMPLITUDE_GRD_HISTEQ
	    fi
	else
	    echo "File $PDF_MERGED_ROT90 exists, skipping ..."
	fi
	    	
	((CPDFS_count+1))
    done
    
    cd $work_PATH/Summary
    png_tiles=$( ls *rot90.png )
    
    echo; echo "Merging files to $output_PATH/Summary/${prefix}-summary.pdf"
    montage -label '%f [%wx%h]' -page 2480x3508 -density 300 -units pixelsperinch $png_tiles -title "Summary $prefix" -quality 90 -tile 1x$CPDFS_count -mode concatenate -verbose -geometry +50+100 "$output_PATH/Summary/${prefix}-summary.pdf"

    # -resize 2480x -page 2480x -extent 2480x -geometry +100+1  -extent 2480x3508
    # if [ $clean_up -gt 0 ]; then
    # 	echo; echo
    # 	echo "Cleaning up"
    # 	rm $DIRECTORY/*.cpt
    # 	rm $CPDFS_dem
    # 	rm $CPDFS_dem_HS
    # 	rm $AMPLITUDE_GRD_HISTEQ
    # 	rm $UNWCONNCOMP_GRD
    # 	rm $UNWSNAPHU_GRD
    # 	rm $AMPLITUDE_GRD
    # 	rm $COHERENCE_PHASE_GRD
    # 	rm $OVERVIEW_DEM2
    # 	rm $OVERVIEW_DEM2_HS	
    # 	echo; echo
    # fi

    CPDFS_end_time=`date +%s`

    CPDFS_runtime=$((CPDFS_end_time - CPDFS_start_time))

    printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n' $(($CPDFS_runtime/86400)) $(($CPDFS_runtime%86400/3600)) $(($CPDFS_runtime%3600/60)) $(($CPDFS_runtime%60))
    echo


fi



    #see more parameters here:
    #http://gmt.soest.hawaii.edu/gmt/html/man/gmtdefaults.html
    #http://www.ruf.rice.edu/~ben/gmt.html
    #http://cosmolinux.no-ip.org/raconetlinux2/gmt.html

    #convert tif to shapefile
    #cd /raid2-manaslu/InSAR/NWArg/TerraSAR-X/Pocitos/isce2stamps/INSAR_20120917/SMALL_BASELINES/20120917_20121111
    #gdal_trace_outline -ndv 0 -b 1 -erosion isce_minrefdem.rg7_az6.amp.wgs84.tif -out-cs ll -dp-toler 10 -ogr-out TerraSAR-X_INSAR_20120917.shp
    #cp -rv TerraSAR-X_INSAR_20120917* /raid-cachi/bodo/Dropbox/Argentina/TerraSAR-X/Pocitos
    #cd /raid-cachi/bodo/Dropbox/Argentina/TerraSAR-X/Pocitos
    #ogr2ogr -f GMT TerraSAR-X_INSAR_20120917.gmt TerraSAR-X_INSAR_20120917.shp

    #cd /raid-cachi/bodo/Dropbox/Argentina/Sentinel1A/Pocitos/orb149_asc
    #/usr/bin/ogr2ogr -f GMT Sentinel1_Pocitos_orb149_ascending.gmt Sentinel1_Pocitos_orb149_ascending.kml
    #cd /raid-cachi/bodo/Dropbox/Argentina/Sentinel1A/Salta/tr76
    #/usr/bin/ogr2ogr -f GMT Sentinel1_Salta_orb76_ascending.gmt Sentinel1_Salta_orb76_ascending.kml

    ###Example Call:
    # bash /raid-cachi/bodo/Dropbox/Argentina/Sentinel1A/Pocitos/plot_S1_maps_gmt_Pocitos.sh
    # 20141023 \
    # 20150127 \
    # rg12_az2 \
    # -10 \
    # 10 \
    # 1 \
    # /raid2-manaslu/InSAR/NWArg/S1/desc/S1_Pocitos_tr83_desc_Rg12_Az2_SRTM1_30m_procstep0_topo_overview_map.ps \
    # /raid2-manaslu/InSAR/NWArg/S1/desc/20141023_20150127/merged/S1_Pocitos_tr83_desc_Rg12_Az2_SRTM1_30m_procstep0_20141023_20150127_amplitude.ps \
    # /raid2-manaslu/InSAR/NWArg/S1/desc/20141023_20150127/merged/S1_Pocitos_tr83_desc_Rg12_Az2_SRTM1_30m_procstep0_20141023_20150127_conncomp.ps \
    # /raid2-manaslu/InSAR/NWArg/S1/desc/20141023_20150127/merged/S1_Pocitos_tr83_desc_Rg12_Az2_SRTM1_30m_procstep0_20141023_20150127_coherence.ps \
    # /raid2-manaslu/InSAR/NWArg/S1/desc/20141023_20150127/merged/S1_Pocitos_tr83_desc_Rg12_Az2_SRTM1_30m_procstep0_20141023_20150127_LOS_mm_yr.ps \
    # /raid2-manaslu/InSAR/NWArg/S1/desc/20141023_20150127/merged/S1_Pocitos_tr83_desc_Rg12_Az2_SRTM1_30m_procstep0_20141023_20150127_combined_map.pdf \
    # /raid-cachi/bodo/Dropbox/Argentina/TerraSAR-X/NEPocitos_stable_fan_DD_WGS84_centroid.gmt \
    # /raid2-manaslu/InSAR/NWArg/S1/desc \
    # -68.5/-64.5/-27/-23 \
    # /raid2-manaslu/InSAR/NWArg/S1/desc
    # demLat_S28_S22_Lon_W070_W062.dem.wgs84
    # S1_Pocitos_tr83_desc_Rg12_Az2_SRTM1_30m_procstep0


    # # Output files
    # POSTSCRIPT1=${7}
    # POSTSCRIPT2=${8}
    # POSTSCRIPT3=${9}
    # POSTSCRIPT4=${10}
    # POSTSCRIPT5=${11}
    # PDF_MERGED=${12}
    # REF_POLYGON=${13}
    # ISCE2STAMPS_DIR=${14}
    # OVERVIEW_REGION=${15}
    # DEM_DIR=${16}
    # DEM_FNAME=${17}
    # LABEL=${18}


    # DEM_GRD="${ISCE2STAMPS_DIR}/${DEM_FNAME}.grd"
    # OVERVIEW_GRD2="${ISCE2STAMPS_DIR}/overview_clip.grd"
    # OVERVIEW_GRD2_HS="${ISCE2STAMPS_DIR}/overview_clip_HS.grd"
    # DEM_GRD2="${ISCE2STAMPS_DIR}/${DEM_FNAME}_clip.grd"
    # DEM_GRD2_HS="${ISCE2STAMPS_DIR}/${DEM_FNAME}_clip_HS.grd"
    # UNWSNAPHU_GRD="${ISCE2STAMPS_DIR}/${master_date}_${slave_date}/merged/${LABEL}_LOS_mm_yr_${master_date}_$slave_date.grd"
    # UNWCONNCOMP_GRD="${ISCE2STAMPS_DIR}/${master_date}_${slave_date}/merged/${LABEL}_conncomp_${master_date}_$slave_date.grd"
    # AMPLITUDE_GRD="${ISCE2STAMPS_DIR}/${master_date}_${slave_date}/merged/${LABEL}_amp_${master_date}_$slave_date.grd"
    # AMPLITUDE_GRD_HISTEQ="${AMPLITUDE_GRD::-4}_histeq.grd"
    # COHERENCE_PHASE_GRD="${ISCE2STAMPS_DIR}/${master_date}_${slave_date}/merged/${LABEL}_phsig_${master_date}_$slave_date.grd"
    # OSM_ROAD_VECTOR_FILE="/raid/data/OSM/SAM_NWArg_roads01.gmt"
    # OSM_ROAD_VECTOR_FILE2="/raid/data/OSM/SAM_NWArg_roads02.gmt"
    # OSM_RIVER_VECTOR_FILE="/raid/data/OSM/SAM_NWArg_rivers.gmt"
    # OSM_LAKES_VECTOR_FILE="/raid/data/OSM/SAM_NWArg_lakes.gmt"
    # OSM_RAILWAY_VECTOR_FILE="/raid/data/OSM/SAM_NWArg_railway.gmt"
    # OSM_VOLCANO_VECTOR_FILE="/raid/data/OSM/SAM_NWArg_volcano.gmt"
    # OSM_WETLANDS_VECTOR_FILE="/raid/data/OSM/SAM_NWArg_wetlands.gmt"
