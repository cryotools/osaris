#!/usr/bin/env bash

######################################################################
#
# OSARIS module to create preview files for grid time series in 
# specified directories.
#
# You may use the following PATH variables:
# $OSARIS_PATH     -> OSARIS' program directory
# $work_PATH       -> Processing directory of a run
# $output_PATH     -> Output dircetory of a run
# $log_PATH        -> Log file directory of a run
# $topo_PATH       -> Directory with dem.grd used by GMTSAR
# $oribts_PATH     -> Directory containing the oribt files
#
#
# David Loibl, 2018
#
#####################################################################

module_name="preview_files"


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
    # Start runtime timer
    module_start=`date +%s`

    # Include the config file
    source ${module_config_PATH}/${module_name}.config




    ############################
    # Module actions start here




    #
    #   now image for google earth
    #
    echo "geocode.csh"
    echo "make the KML files for Google Earth"
    grd2kml.csh display_amp_ll display_amp.cpt
    grd2kml.csh corr_ll corr.cpt
    grd2kml.csh phase_mask_ll phase.cpt
    grd2kml.csh phasefilt_mask_ll phase.cpt
    #ln -s phasefilt_mask_ll.grd phase_mask_ll_bw.grd
    #grd2kml.csh phase_mask_ll_bw phase_bw.cpt
    #rm phase_mask_ll_bw.grd
    if [ -e xphase_mask_ll.grd ]; then
	grd2kml.csh xphase_mask_ll phase_grad.cpt
	grd2kml.csh yphase_mask_ll phase_grad.cpt
    fi
    if [ -e unwrap_mask_ll.grd ]; then
	grd2kml.csh unwrap_mask_ll unwrap.cpt
    fi
    if [ -e phasefilt_mask_ll.grd ]; then
	grd2kml.csh phasefilt_mask_ll phase.cpt
    fi
    if [ -e unwrap_mask_ll.grd ]; then

	#######
	# Obsolete, now included in displacement module ...
	#######
	# # constant is negative to make LOS = -1 * range change
	# # constant is (1000 mm) / (4 * pi)
	#  gmt grdmath unwrap_mask_ll.grd $wavel MUL -79.58 MUL = los_ll.grd 

	gmt grdedit -D//"mm"/1///"$PWD:t LOS displacement"/"equals negative range" los_ll.grd 

	grd2kml.csh los_ll los.cpt
    fi








    # Module actions end here
    ###########################



    # Stop runtime timer and print runtime
    module_end=`date +%s`    
    module_runtime=$((module_end-module_start))

    echo
    printf 'Processing finished in %02dd %02dh:%02dm:%02ds\n\n' \
	$(($module_runtime/86400)) \
	$(($module_runtime%86400/3600)) \
	$(($module_runtime%3600/60)) \
	$(($module_runtime%60))
    echo
fi



    # #
    # #   look at the masked phase
    # #
    # set boundR = `gmt grdinfo display_amp.grd -C | awk '{print ($3-$2)/4}'`
    # set boundA = `gmt grdinfo display_amp.grd -C | awk '{print ($5-$4)/4}'`
    # gmt grdimage phase_mask.grd -JX6.5i -Cphase.cpt -B"$boundR":Range:/"$boundA":Azimuth:WSen -X1.3i -Y3i -P -K > phase_mask.ps
    # gmt psscale -D3.3/-1.5/5/0.2h -Cphase.cpt -B1.57:"phase, rad": -O >> phase_mask.ps
    # if [ -e xphase_mask.grd ]; then
    # 	gmt grdimage xphase_mask.grd -JX8i -Cphase_grad.cpt -X.2i -Y.5i -P > xphase_mask.ps
    # 	gmt grdimage yphase_mask.grd -JX8i -Cphase_grad.cpt -X.2i -Y.5i -P > yphase_mask.ps
    # fi
    # if [ -e unwrap_mask.grd ] then 
    # 	gmt grdimage unwrap_mask.grd -JX6.5i -B"$boundR":Range:/"$boundA":Azimuth:WSen -Cunwrap.cpt -X1.3i -Y3i -P -K > unwrap_mask.ps
    # 	std=`gmt grdinfo -C -L2 unwrap_mask.grd | awk '{printf("%5.1f", $13)}'`
    # 	gmt psscale -D3.3/-1.5/5/0.2h -Cunwrap.cpt -B"$std":"unwrapped phase, rad": -O -E >> unwrap_mask.ps
    # fi
    # if [ -e phasefilt_mask.grd]; then 
    # 	gmt grdimage phasefilt_mask.grd -JX6.5i -B"$boundR":Range:/"$boundA":Azimuth:WSen -Cphase.cpt -X1.3i -Y3i -P -K > phasefilt_mask.ps
    # 	gmt psscale -D3.3/-1.5/5/0.2h -Cphase.cpt -B1.57:"phase, rad": -O >> phasefilt_mask.ps
    # fi
    # # line-of-sight displacement
    # if [ -e unwrap_mask.grd]; then
	
    # 	#######
    # 	# Obsolete, now included in displacement module ...
    # 	#######
    # 	# wavel=`grep wavelength *.PRM | awk '{print($3)}' | head -1 `
    # 	# gmt grdmath unwrap_mask.grd $wavel MUL -79.58 MUL = los.grd
    # 	#######

    # 	gmt grdgradient los.grd -Nt.9 -A0. -Glos_grad.grd
    # 	tmp=`gmt grdinfo -C -L2 los.grd`
    # 	limitU=`echo $tmp | awk '{printf("%5.1f", $12+$13*2)}'`
    # 	limitL=`echo $tmp | awk '{printf("%5.1f", $12-$13*2)}'`
    # 	std=`echo $tmp | awk '{printf("%5.1f", $13)}'`
    # 	gmt makecpt -Cpolar -Z -T"$limitL"/"$limitU"/1 -D > los.cpt
    # 	gmt grdimage los.grd -Ilos_grad.grd -Clos.cpt -B"$boundR":Range:/"$boundA":Azimuth:WSen -JX6.5i -X1.3i -Y3i -P -K > los.ps
    # 	gmt psscale -D3.3/-1.5/4/0.2h -Clos.cpt -B"$std":"LOS displacement, mm":/:"range decrease": -O -E >> los.ps 
    # fi
