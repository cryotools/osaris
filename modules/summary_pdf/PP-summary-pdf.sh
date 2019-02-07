#!/usr/bin/env bash

start=`date +%s`

config_file=$1
work_PATH=$2
pair_id=$3

echo "Config file: $config_file"
echo "Work path:   $work_PATH"
echo "Pair ID:     $pair_id"

source $config_file

# Convert dataset configuration to arrays
labels=( "$LABEL_1" "$LABEL_2" "$LABEL_3" "$LABEL_4" )
directories=( "$DIRECTORY_1" "$DIRECTORY_2" "$DIRECTORY_3" "$DIRECTORY_4" )
histeqs=( "$HIST_EQ_1" "$HIST_EQ_2" "$HIST_EQ_3" "$HIST_EQ_4" )
cpts=( $CPT_1 $CPT_2 $CPT_3 $CPT_4 )
ranges=( $RANGE_1 $RANGE_2 $RANGE_3 $RANGE_4 )
show_suppls=( $SHOW_SUPPL_1 $SHOW_SUPPL_2 $SHOW_SUPPL_3 $SHOW_SUPPL_4 )

dem_grd_hs="$work_PATH/Summary/hillshade.grd"
CPDFS_dem="$work_PATH/Summary/CPDFS_dem.grd"
CPDFS_dem_HS="$work_PATH/Summary/CPDFS_dem_HS.grd"

ps_base="$work_PATH/Summary/${pair_id}-grd"	
histeq_base="$work_PATH/Summary/${pair_id}-hiq"
pdf_merged="$work_PATH/Summary/${pair_id}-combined.pdf"
pdf_merged_ROT90=${pdf_merged::-4}_rot90.png


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



if [ ! -f "$pdf_merged_ROT90" ]; then

    GRD_FAIL=( 0 0 0 0 )

    for counter in 0 1 2 3; do 
	echo "Preparing ${labels[$counter]} ..."
	echo "Searching for files in ${directories[$counter]}"
	cpt_files[$counter]="$work_PATH/Summary/grd_${counter}_color.cpt"
	cd ${directories[$counter]}
	ls_result=$( ls ${pair_id}*.grd )
	echo "Found file $ls_result"
	if [ -f $ls_result ]; then		    	    
	    GRD[$counter]="${directories[$counter]}/$ls_result"
	    echo "${labels[$counter]} file found: ${GRD[$counter]}"		
	    
	    echo "histeqs $counter : ${histeqs[$counter]}"

	    if [ ${histeqs[$counter]} -eq "1" ]; then
		if [ ! -f ${histeq_base}-$counter.grd ]; then
    		    echo; echo "Calculate histogram equalization for ${GRD[$counter]}"
    		    gmt grdhisteq ${GRD[$counter]} -G${histeq_base}-$counter.grd -N -V
    		    gmt grd2cpt -E15 ${histeq_base}-$counter.grd -C${cpts[$counter]} -V > $work_PATH/Summary/grd_${counter}.cpt
		else
		    echo; echo "${labels[$counter]} histogram exists, skipping ..."; echo
		fi
	    fi
	else
	    echo "No ${labels[$counter]} file found"
	    GRD_FAIL[$counter]=1
	    GRD_MESSAGE[$counter]="No ${labels[$counter]} file"
	fi
    done


    
    cd $work_PATH/Summary

    SCALE=18  
    XSTEPS=0.5
    YSTEPS=0.5	

    if [ ! -e $pdf_merged ]; then
	for counter in 0 1 2 3; do
    	    if [ ! -e ${ps_base}-$counter.ps ]; then
		echo; echo "Creating ${labels[$counter]} in ${ps_base}-$counter.ps"		
		TITLE="${labels[$counter]} {master_date}"			
		if [ ! "${GRD_FAIL[$counter]}" -eq 1 ]; then
		    if [ ${histeqs[$counter]} -eq 1 ]; then
			echo; echo "${labels[$counter]}: ${histeq_base}-$counter.grd"; echo
			gmt grdimage ${histeq_base}-$counter.grd  \
			    -C$work_PATH/Summary/grd_${counter}.cpt -R$AOI_REGION -JM$SCALE -B+t"$TITLE" -Q \
			    -Bx$XSTEPS -By$YSTEPS -V -K -Yc -Xc > ${ps_base}-$counter.ps
		    else
			gmt grdimage ${GRD[$counter]}  \
			    -C${cpt_files[$counter]} -R$AOI_REGION -JM$SCALE -B+t"$TITLE" -Q \
			    -Bx$XSTEPS -By$YSTEPS -V -K -Yc -Xc > ${ps_base}-$counter.ps
		    fi
		    
		    if [ ${show_suppls[$counter]} -eq 1 ]; then
			for vector_file in ${vector_files[@]}; do
			    style_name=${vector_file}_style
			    vector_style=$( echo "${!style_name}" | tr -d "'" )
			    gmt psxy $vector_style -JM$SCALE -R$AOI_REGION ${!vector_file::-4}.gmt -O -K -V >> ${ps_base}-$counter.ps			    				
			done
		    fi
		else			
		    gmt grdimage $CPDFS_dem_HS -C#ffffff,#eeeeee \
			-R$AOI_REGION -JM$SCALE -B+t"${GRD_MESSAGE[$counter]}" -Q -Bx$XSTEPS -By$YSTEPS -V -K -Yc -Xc > ${ps_base}-$counter.ps
		    
		    
		    if [ $page_orientation -eq 1 ]; then
			convert -density $resolution -fill red -pointsize 18 -gravity center \
			    -trim -verbose label:"${GRD_MESSAGE[$counter]}" \
			    ${ps_base}-$counter.ps -quality 100  ${ps_base}-$counter.ps
		    else
			convert -rotate 90 -density $resolution -fill red -pointsize 18 -gravity center \
			    -trim -verbose label:"${GRD_MESSAGE[$counter]}" \
			    ${ps_base}-$counter.ps -quality 100  ${ps_base}-$counter.ps
		    fi
		fi
		
		if [ $page_orientation -eq 1 ]; then
		    convert -verbose -density $resolution -trim  ${ps_base}-$counter.ps -quality 100 ${ps_base}-$counter.png
		else
		    convert -verbose -rotate 90 -density $resolution -trim  ${ps_base}-$counter.ps -quality 100 ${ps_base}-$counter.png
		fi
	    else
		echo; echo "${labels[$counter]} in ${ps_base}-$counter.ps exists, skipping ..."
    	    fi
	done

	
    	echo "Merging PS into $pdf_merged_ROT90"
	take_diff=$(( ($(date --date="$slave_date" +%s) - $(date --date="$master_date" +%s) )/(60*60*24) ))
	if [ "$page_orientation" -eq 1 ]; then
    	    montage ${ps_base}-0.png ${ps_base}-1.png ${ps_base}-2.png ${ps_base}-3.png  \
		-rotate 90 -geometry +100+150 -density $resolution -title "${pair_id} (${take_diff} days)" \
		-quality 100 -tile 4x1 -mode concatenate -verbose $pdf_merged_ROT90
	else
	    montage -tile 1x4 -geometry +20+30 \
		${ps_base}-0.png ${ps_base}-1.png ${ps_base}-2.png ${ps_base}-3.png  \
		-title "${pair_id} (${take_diff} days)" \
		-density $resolution -quality 100 -mode concatenate -verbose $pdf_merged_ROT90
	fi


	if [ "$clean_up" -ge 1 ]; then
    	    rm ${ps_base}_*.ps 
	    rm ${ps_base}_*.png
	fi
	
	if [ "${histeq_base}-$counter.grd" != "$CPDFS_dem_HS" ]; then
	    rm ${histeq_base}-*.grd
	fi
    fi
else
    echo "File $pdf_merged_ROT90 exists, skipping ..."
fi


if [ -f $pdf_merged_ROT90 ]; then status_SUMMARY=1; else status_SUMMARY=0; fi

end=`date +%s`
runtime=$((end-start))

echo "${pair_id:0:8} ${pair_id:10:8} $SLURM_JOB_ID $runtime $status_SUMMARY" >> $output_PATH/Reports/PP-SUMMARY-stats.tmp

printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n' $(($runtime/86400)) $(($runtime%86400/3600)) $(($runtime%3600/60)) $(($runtime%60))


