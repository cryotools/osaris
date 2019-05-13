#!/usr/bin/env bash

#################################################################
#
# Interferometric processing routines.
#
# Based on GMTSAR's p2p_S1_TOPS.csh by David Sandwell. 
# Usage: prep.sh master_scene slave_scene GMTSAR_config_file OSARIS_PATH boundary_box.xyz
#
################################################################

# alias rm 'rm -f'
# unset noclobber

if [ $# -lt 4 ]; then
    echo; echo "Usage: intf.sh master_scene slave_scene GMTSAR_config_file OSARIS_PATH boundary_box.xyz"; echo
    echo "Example: intf.sh S1A20150526_F1 S1A20150607_F1 config.tsx.slc.txt home/user/osaris /workpath/boundary_box.xyz"; echo; echo
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




# INTERFEROMETRIC PROCESSING

if [ $proc_stage -le 4 ]; then
    echo; echo "Interferometric processing ..."; echo
    # Clean up
    cleanup.csh intf
    
    # Make and filter interferograms

    cd intf/
    
    # set ref_id  = `grep SC_clock_start ../raw/$master.PRM | awk '{printf("%d",int($3))}' `
    # set rep_id  = `grep SC_clock_start ../raw/$slave.PRM | awk '{printf("%d",int($3))}' `
    # mkdir $ref_id"_"$rep_id
    # cd $ref_id"_"$rep_id

    ln -s ../raw/$ref.LED . 
    ln -s ../raw/$rep.LED .
    ln -s ../SLC/$ref.SLC . 
    ln -s ../SLC/$rep.SLC .
    cp ../SLC/$ref.PRM . 
    cp ../SLC/$rep.PRM .

    if [ $topo_phase -eq 1 ]; then
	if [ $shift_topo -eq 1 ]; then
            ln -s ../topo/topo_shift.grd .
            intf.csh $ref.PRM $rep.PRM -topo topo_shift.grd  
            # filter.csh $ref.PRM $rep.PRM $filter $dec_factor 
	else 
            ln -s ../topo/topo_ra.grd . 
            intf.csh $ref.PRM $rep.PRM -topo topo_ra.grd 
            # filter.csh $ref.PRM $rep.PRM $filter $dec_factor 
	fi
    else
	intf.csh $ref.PRM $rep.PRM
	# filter.csh $ref.PRM $rep.PRM $filter $dec_factor 
    fi
    # echo "Executing     filter.csh $ref.PRM $rep.PRM $filter_wavelength $dec_factor "
    # filter.csh ${ref}.PRM ${rep}.PRM $filter_wavelength $dec_factor 
    # cp -u *gauss* ../../
    cd ..
else
    echo; echo "Skipping interferometric processing (proc_stage set to ${proc_stage})"; echo
fi
