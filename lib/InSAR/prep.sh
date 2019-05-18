#!/usr/bin/env bash

#################################################################
#
# Preparation of InSAR processing routines.
#
# Based on GMTSAR's p2p_S1_TOPS.csh by David Sandwell. 
# Usage: prep.sh master_scene slave_scene GMTSAR_config_file OSARIS_PATH boundary_box.xyz
#
################################################################

# alias rm 'rm -f'
# unset noclobber

if [ $# -lt 4 ]; then
    echo; echo "Usage: prep.sh master_scene slave_scene GMTSAR_config_file OSARIS_PATH boundary_box.xyz"; echo
    echo "Example: prep.sh S1A20150526_F1 S1A20150607_F1 config.tsx.slc.txt home/user/osaris /workpath/boundary_box.xyz"; echo; echo
    exit 1
fi

# Check if files exist

OSARIS_PATH=$4

if [ ! -f raw/$1.PRM ] || [ ! -f raw/$1.LED ] || [ ! -f raw/$1.SLC ]; then
    echo " Missing input file raw/$1"; exit
fi

if [ ! -f raw/$2.PRM ] || [ ! -f raw/$2.LED ] || [ ! -f raw/$2.SLC ]; then
    echo " Missing input file raw/$2"; exit
fi

if [ ! -f $3 ]; then
    echo " Missing config file: $3"
    exit
fi

 
# Read parameters from config file
source $3

# Check if vars are set, set to default values if not
if [ -z $proc_stage ]; then        proc_stage=1; fi

# Vars for interferometric processing 
if [ -z $earth_radius ]; then      earth_radius=0; fi
if [ -z $topo_phase ]; then        topo_phase=1; fi
if [ -z $shift_topo ]; then        shift_topo=0; fi
if [ -z $switch_master ]; then     switch_master=0; fi


if [ -z $filter_wavelength ]; then filter_wavelength=100; fi
if [ -z $dec_factor ]; then        dec_factor=0; fi
if [ -z $threshold_snaphu ]; then  threshold_snaphu=0.1; fi
if [ -z $threshold_geocode ]; then threshold_geocode=0; fi
if [ -z $region_cut ]; then        region_cut=0; fi
if [ -z $switch_land ]; then       switch_land=0; fi
if [ -z $defomax ]; then           defomax=0; fi

# Read scenes
master=$1 
slave=$2 

if [ $switch_master -eq 1 ]; then
    ref=$slave
    rep=$master
else
    ref=$master
    rep=$slave
fi

# Make working directories
mkdir -p intf/ SLC/


# PREPROCESSING
if [ $proc_stage -eq 1 ]; then
    echo; echo "Preprocessing interferometric data ..."; echo
    # Preprocess the raw data
    cd raw

    # Copy the PRM to PRM00 in case the script is run a second time
    if [ -e $master.PRM00 ]; then
       cp $master.PRM00 $master.PRM
       cp $slave.PRM00 $slave.PRM
    else
       cp $master.PRM $master.PRM00
       cp $slave.PRM $slave.PRM00
    fi
    
    # Set num_lines to be the min of the master and slave

    # @ m_lines = $( grep num_lines ../raw/$master.PRM | awk '{printf("%d",int($3))}' )
    # @ s_lines = `grep num_lines ../raw/$slave.PRM | awk '{printf("%d",int($3))}' `
    # m_lines=$( grep num_lines ../raw/$master.PRM | awk '{print $3}' )
    # s_lines=$( grep num_lines ../raw/$slave.PRM | awk '{print $3}' )

    m_lines=$( awk '/num_lines/ {print int($3)}' ../raw/$master.PRM )
    s_lines=$( awk '/num_lines/ {print int($3)}' ../raw/$slave.PRM )
    
    # num_lines_comp=$( echo  "$s_lines <  $m_lines" | bc -l )
    # echo "s_lines <  m_lines: $s_lines <  $m_lines | bc -l"
    # echo "result: $num_lines_comp"; echo
    # if [ $( echo "$s_lines <  $m_lines" | bc -l ) -eq 1 ]; then

    if [ $s_lines -lt $m_lines ]; then
      update_PRM.csh $master.PRM num_lines $s_lines
      update_PRM.csh $master.PRM num_valid_az $s_lines
      update_PRM.csh $master.PRM nrows $s_lines
    else
      update_PRM.csh $slave.PRM num_lines $m_lines
      update_PRM.csh $slave.PRM num_valid_az $m_lines
      update_PRM.csh $slave.PRM nrows $m_lines
    fi

    # Set the higher Doppler terms to zerp to be zero

    update_PRM.csh $master.PRM fdd1 0
    update_PRM.csh $master.PRM fddd1 0

    update_PRM.csh $slave.PRM fdd1 0
    update_PRM.csh $slave.PRM fddd1 0

    rm -f *.log *.PRM0

    cd ..

else
    echo; echo "Skipping preprocessing of interferometric data (proc_stage set to ${proc_stage})"; echo
fi



# FOCUS AND ALIGN SLCs

if [ $proc_stage -le 2 ]; then
    echo; echo "Focussing and aligning SLCs ..."; echo

    # Clean up 
    cleanup.csh SLC &> /dev/null

    # Align SLC images  
    cd SLC
    cp ../raw/*.PRM ../raw/*.LED .
    ln -s ../raw/$master.SLC .
    ln -s ../raw/$slave.SLC .
    # ln -s ../raw/$master.LED . 
    # ln -s ../raw/$slave.LED .
    
    # cp $slave.PRM $slave.PRM0
    # resamp $master.PRM $slave.PRM $slave.PRMresamp $slave.SLCresamp 1
    # if [ -f $slave.PRMresamp ] && [ -f $slave.SLCresamp ]; then
    # 	echo "Succesfully generated aligned PRM and SLC files"
    # 	rm -f $slave.SLC
    # 	mv $slave.SLCresamp $slave.SLC
    # 	cp $slave.PRMresamp $slave.PRM
    # else 
    # 	echo "WARNING: Focus and align routine failed. Proceeding with original files."
    # fi
    cd ..
else 
    echo; echo "Skipping focussing and aligning of SLCs (proc_stage set to ${proc_stage})"; echo
fi



# TOPOPHASE PROCESSING
if [ $proc_stage -le 3 ]; then
    echo; echo "Topophase processing ..."; echo
    # Clean up
    cleanup.csh topo &> /dev/null
    
    # Make topo_ra if there is dem.grd

    if [ $topo_phase -eq 1 ]; then 
	cd topo
	cp ../SLC/$master.PRM master.PRM 
	ln -s ../raw/$master.LED . 

	if [ -f dem.grd ]; then
            echo "Obtaining topophase using DEM ..."
            dem2topo_ra.csh master.PRM dem.grd 
	    if [ -f topo_ra.grd ]; then
		echo "Topophase grid created successfully."
	    else
		echo "WARNING: Failure trying to create topophase grid!"
	    fi
	else 
            echo "WARNING: No DEM file found. Skipping topographic phase removal ... "
            exit 1
	fi

	cd .. 

	# Shift topo_ra

	if [ $shift_topo -eq 1 ]; then 
            
	    echo; echo "Procssing topo radar offset ..."

	    # Make sure the range increment of the amplitude image matches the topo_ra.grd
            rng=$(grdinfo topo/topo_ra.grd | grep x_inc | awk '{print $7}')

            cd SLC 
            echo " range decimation is: $rng"
	    echo " Executing slc2amp.csh $master.PRM $rng amp-$master.grd"
            slc2amp.csh $master.PRM $rng amp-$master.grd
	    echo " Finished slc2amp.csh "

            cd ../topo
            ln -s ../SLC/amp-$master.grd . 
	    echo " Executing offset_topo "
            offset_topo amp-$master.grd topo_ra.grd 0 0 7 topo_shift.grd 
	    echo " Finished offset_topo "
            cd ..
            echo "OFFSET_TOPO - END"
	elif [ $shift_topo -eq 0 ]; then 
            echo "NO TOPO_RA SHIFT "
	else 
            echo "Wrong paramter: shift_topo $shift_topo"
            exit 1
	fi

    elif [ $topo_phase -eq 0 ]; then 
	echo "NO TOPO_RA IS SUBSTRACTED"
    else 
	echo "Wrong paramter: topo_phase $topo_phase"
	exit 1
    fi
else
    echo; echo "Skipping topophase processing (proc_stage set to ${proc_stage})"; echo
fi



