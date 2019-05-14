#!/usr/bin/env bash

#################################################################
#
# Merge multiple swath (if neccessary), then perform phase unwrappping and geocoding.
#
# Based on GMTSAR's merge_unwrap_geocode.csh by Xiaohua(Eric) Xu, 2016. 
#
################################################################

if [ ! $# -eq 3 ]; then
    echo ""
    echo "Usage: merge_unwrap_geocode_tops.csh inputfile config_file boundary_box_file"
    echo ""
    echo "Note: Inputfiles should be as following:"
    echo ""
    echo "      Swath1_Path:Swath1_master.PRM:Swath1_repeat.PRM"
    echo "      Swath2_Path:Swath2_master.PRM:Swath2_repeat.PRM"
    echo "      Swath3_Path:Swath3_master.PRM:Swath3_repeat.PRM"
    echo "      (Use the repeat PRM which contains the shift information.)"
    echo "      e.g. ../F1/intf/2015016_2015030/:S1A20151012_134357_F1.PRM"
    echo ""
    echo "      Make sure under each path, the processed phasefilt.grd, corr.grd and mask.grd exist."
    echo "      Also make sure the dem.grd is linked. "
    echo ""
    echo "      config_file is the same one used for processing."
    echo ""
    echo "Example: merge_unwrap_geocode_tops.csh filelist batch.config"
    echo ""
    exit 1
fi

if [ -f tmp_phaselist ]; then rm tmp_phaselist; fi
if [ -f tmp_corrlist ]; then rm tmp_corrlist; fi
if [ -f tmp_masklist ]; then rm tmp_masklist; fi
if [ -f tmp_amplist ]; then rm tmp_amplist; fi

if [ ! -f dem.grd  ]; then
    echo "Please link dem.grd to current folder"
    exit 1
fi

if [ ! -f $2 ]; then
    echo "ERROR: Configuration file not found at $2. Aborting merge-unwrap-geocode routine ..."
    exit 1
else
    source $2
    # Read in parameters
    # threshold_snaphu=$( grep threshold_snaphu $2 | awk '{print $3}' )
    # threshold_geocode=$( grep threshold_geocode $2 | awk '{print $3}' )
    # #  region_cut=$( grep region_cut $2 | awk '{print $3}' )
    # switch_land=$( grep switch_land $2 | awk '{print $3}' )
    # defomax=$( grep defomax $2 | awk '{print $3}' )
    # near_interp=$( grep near_interp $2 | awk '{print $3}' )

fi


# input="lists.txt"

# ## Let us read a file line-by-line using while loop ##
# while IFS= read -r line
# do
#     printf 'Working on %s file...\n' "$line"
# done < "$input"



num_swaths=$( cat $1 | wc -l )

if [ $num_swaths -gt 1 ]; then
    echo; echo "$num_swaths swaths found. Merging ..."; echo
    # Creating inputfiles for merging
    while IFS= read -r line; do
	# foreach line $( awk '{print $0}' $1 )
	now_dir=$( pwd )
	pth=$( echo $line | awk -F: '{print $1}' )
	prm=$( echo $line | awk -F: '{print $2}' )
	prm2=$( echo $line | awk -F: '{print $3}' )
	cd $pth
	rshift=$( grep rshift $prm2 | tail -1 | awk '{print $3}' )
	fs1=$( grep first_sample $prm | awk '{print $3}' )
	fs2=$( grep first_sample $prm2 | awk '{print $3}' )
	cp $prm tmp.PRM
	if [ $fs2 > $fs1 ]; then
	    update_PRM tmp.PRM first_sample $fs2
	fi
	update_PRM tmp.PRM rshift $rshift
	cd $now_dir

	echo $pth"tmp.PRM:"$pth"phasefilt.grd" >> tmp_phaselist
	echo $pth"tmp.PRM:"$pth"corr.grd" >> tmp_corrlist
	echo $pth"tmp.PRM:"$pth"mask.grd" >> tmp_masklist
	echo $pth"tmp.PRM:"$pth"display_amp.grd" >> tmp_amplist
    done < "$1"


    pth=$( awk -F: 'NR==1 {print $1}' $1 )
    stem=$( awk -F: 'NR==1 {print $2}' $1 | awk -F"." '{print $1}' )
    #echo $pth $stem

    echo ""
    echo "Merging START"
    merge_swath tmp_phaselist phasefilt.grd $stem
    merge_swath tmp_corrlist corr.grd
    merge_swath tmp_masklist mask.grd
    merge_swath tmp_amplist display_amp.grd
    echo "Merging END"
    echo ""

    if [ ! -f trans.dat ]; then
	led=$( grep led_file $pth$stem".PRM" | awk '{print $3}' )
	cp $pth$led .
    fi
else
    # Only one swath. Prepare files directly
    pth=$( awk -F: 'NR==1{print $1}' $1 )
    echo; echo "Only one swath found in $pth"; echo
    cd $pth
fi

# This step is essential, cut the DEM so it can run faster.
if [ ! -f trans.dat ]; then
    # led=$( grep led_file $pth$stem".PRM" | awk '{print $3}' )
    # cp $pth$led .
    echo "Recomputing the projection LUT..."
    # Need to compute the geocoding matrix with supermaster.PRM with rshift  to 0
    rshift=$( grep rshift $stem".PRM" | tail -1 | awk '{print $3}' )
    update_PRM $stem".PRM" rshift 0
    gmt grd2xyz --FORMAT_FLOAT_OUT=%lf dem.grd -s | SAT_llt2rat $stem".PRM" 1 -bod > trans.dat
    #  rshift back for other usage
    update_PRM $stem".PRM" rshift $rshift
fi


# TODO: Check which range and azimuth coordinates are actually representing the boundary box
#       -> Check all 4 lon/lat combinations
#       -> Set negative values to 0
#       -> Set values > the maximum (see PRM files) to maximum
#       -> This must be applied to both p2p...csh and merge_unwrap...csh

if [ -e ../proc-params/cut_to_aoi.flag ]; then
    cut_to_aoi=$( cat ../proc-params/cut_to_aoi.flag )
    if [ $cut_to_aoi == 1 ]; then

	if [ ! -f $3 ]; then
	    echo "No valid boundary box file provided. Phase unwrapping will be conducted on the whole scene extent."
	else
	    SAT_llt2rat $stem".PRM" 1 < $3 > boundary_box_ra.xyz
	    bb_range_1=$( awk 'NR==1{ print $1 }' boundary_box_ra.xyz )
	    bb_range_2=$( awk 'NR==2{ print $1 }' boundary_box_ra.xyz )
	    bb_range_3=$( awk 'NR==3{ print $1 }' boundary_box_ra.xyz )
	    bb_range_4=$( awk 'NR==4{ print $1 }' boundary_box_ra.xyz )
	    bb_azimu_1=$( awk 'NR==1{ print $2 }' boundary_box_ra.xyz )
	    bb_azimu_2=$( awk 'NR==2{ print $2 }' boundary_box_ra.xyz )
	    bb_azimu_3=$( awk 'NR==3{ print $2 }' boundary_box_ra.xyz )
	    bb_azimu_4=$( awk 'NR==4{ print $2 }' boundary_box_ra.xyz )


	    # Find min/max values for radar boundary box coordinates
	    range_max=$bb_range_1
	    range_min=$bb_range_1
	    azimu_max=$bb_azimu_1
	    azimu_min=$bb_azimu_1
	    
	    for corner_nr in {2..4}; do
		rng_name="bb_range_$corner_nr"
		azi_name="bb_azimu_$corner_nr"
		if [ ! -z ${!rng_name} ]; then
		    if [ $( echo "${!rng_name} > $range_max" | bc -l ) == 1 ]; then range_max=${!rng_name}; fi
		    if [ $( echo "${!rng_name} < $range_min" | bc -l ) == 1 ]; then range_min=${!rng_name}; fi
		fi
		if [ ! -z ${!azi_name} ]; then
		    if [ $( echo "${!azi_name} > $azimu_max" | bc -l ) == 1 ]; then azimu_max=${!azi_name}; fi
		    if [ $( echo "${!azi_name} < $azimu_min" | bc -l ) == 1 ]; then azimu_min=${!azi_name}; fi
		fi

	    done


	    # if [ $( echo "$bb_range_2 > $range_max" | bc -l ) == 1 ]; then range_max=$bb_range_2; fi
	    # if [ $( echo "$bb_range_3 > $range_max" | bc -l ) == 1 ]; then range_max=$bb_range_3; fi
	    # if [ $( echo "$bb_range_4 > $range_max" | bc -l ) == 1 ]; then range_max=$bb_range_4; fi

	    # range_min=$bb_range_1
	    # if [ $( echo "$bb_range_2 < $range_min" | bc -l ) == 1 ]; then range_min=$bb_range_2; fi
	    # fi
	    # if [ $( echo "$bb_range_3 < $range_min" | bc -l ) == 1 ]; then
	    # 	range_min=$bb_range_3
	    # fi
	    # if [ $( echo "$bb_range_4 < $range_min" | bc -l ) == 1 ]; then
	    # 	range_min=$bb_range_4
	    # fi

	    # azimu_max=$bb_azimu_1
	    # if [ $( echo "$bb_azimu_2 > $azimu_max" | bc -l ) == 1 ]; then
	    # 	azimu_max=$bb_azimu_2
	    # fi
	    # if [ $( echo "$bb_azimu_3 > $azimu_max" | bc -l ) == 1 ]; then
	    # 	azimu_max=$bb_azimu_3
	    # fi
	    # if [ $( echo "$bb_azimu_4 > $azimu_max" | bc -l ) == 1 ]; then
	    # 	azimu_max=$bb_azimu_4
	    # fi

	    # azimu_min=$bb_azimu_1
	    # if [ $( echo "$bb_azimu_2 < $azimu_min" | bc -l ) == 1 ]; then
	    # 	azimu_min=$bb_azimu_2
	    # fi
	    # if [ $( echo "$bb_azimu_3 < $azimu_min" | bc -l ) == 1 ]; then
	    # 	azimu_min=$bb_azimu_3
	    # fi
	    # if [ $( echo "$bb_azimu_4 < $azimu_min" | bc -l ) == 1 ]; then
	    # 	azimu_min=$bb_azimu_4
	    # fi

	    region_cut=$range_min"/"$range_max"/"$azimu_min"/"$azimu_max
	    echo "Var region_cut set to "$region_cut
	fi
    else 
	echo "No cutting to area of interest"
	region_cut=0
    fi
fi




# Unwrapping
if [ $region_cut == "" ]; then
    region_cut=$( gmt grdinfo phasefilt.grd -I- | cut -c3-20 )
fi
if [ $threshold_snaphu != 0  ]; then
    if [ $switch_land == 1 ]; then
	if [ ! -f landmask_ra.grd ]; then
            landmask.csh $region_cut
	fi
    fi

    echo ""
    echo "SNAPHU.CSH - START"
    echo "threshold_snaphu: $threshold_snaphu"

    $OSARIS_PATH/lib/GMTSAR-mods/snaphu_OSARIS.csh $threshold_snaphu $defomax $region_cut


    # if [ $near_interp == 1 ]; then
    #   snaphu_interp.csh $threshold_snaphu $defomax $region_cut
    # else
    #   snaphu.csh $threshold_snaphu $defomax $region_cut
    # fi

    echo "SNAPHU.CSH - END"
else
    echo ""
    echo "SKIP UNWRAP PHASE"
fi

# Geocoding 
#if [ -f raln.grd) rm raln.grd
#if [ -f ralt.grd) rm ralt.grd

# if [ $threshold_geocode != 0 ]; then
echo ""
echo "GEOCODE-START"

gmt grdmath phasefilt.grd mask.grd MUL=phasefilt_mask.grd -V

$OSARIS_PATH/lib/GMTSAR-mods/geocode_OSARIS.csh $threshold_geocode $3 $cut_to_aoi


# 
# proj_ra2ll.csh trans.dat phasefilt.grd phasefilt_ll.grd
# proj_ra2ll.csh trans.dat phasefilt_mask.grd phasefilt_mask_ll.grd
# proj_ra2ll.csh trans.dat corr.grd corr_ll.grd
# proj_ra2ll.csh trans.dat con_comp.grd con_comp_ll.grd
# # gmt makecpt -Crainbow -T-3.15/3.15/0.05 -Z > phase.cpt
# #  BT=$( gmt grdinfo -C corr.grd | awk '{print $7}' )
# # gmt makecpt -Cgray -T0/$BT/0.05 -Z > corr.cpt
# # grd2kml.csh phasefilt_ll phase.cpt
# # grd2kml.csh corr_ll corr.cpt

# if [ -f unwrap.grd ]; then
#   gmt grdmath unwrap.grd mask.grd MUL=unwrap_mask.grd -V
#   proj_ra2ll.csh trans.dat unwrap.grd unwrap_ll.grd
#   proj_ra2ll.csh trans.dat unwrap_mask.grd unwrap_mask_ll.grd
#   #  BT=$( gmt grdinfo -C unwrap.grd | awk '{print $7}' )
#   #  BL=$( gmt grdinfo -C unwrap.grd | awk '{print $6}' )
#   # gmt makecpt -T$BL/$BT/0.5 -Z > unwrap.cpt
#   # grd2kml.csh unwrap_mask_ll unwrap.cpt
#   # grd2kml.csh unwrap_ll unwrap.cpt
# fi

echo "GEOCODE END"


rm tmp_phaselist tmp_corrlist tmp_masklist *.eps *.bb
