#!/bin/bash
######################################################################
#   Xiaohua(Eric) Xu
#   June 2016
# 04
# script to prepare directory and process SBAS
# GMT5SAR processing for sentinel1A/B
# 2017.02.22 "Noorlaila Hayati"
# email: n.isya@tu-braunschweig.de or noorlaila@geodesy.its.ac.id
######################################################################

#if [[ $# -ne 2 ]]; then
#    echo ""
#    echo "Usage: prep_proc_SBAS.sh data.tab mode"
#    echo ""
#    echo "  script to prepare directory and process SBAS"
#    echo ""
#    echo "  example : prep_proc_SBAS.sh data.tab 1"
#    echo ""
#    echo "  format of data.tab:"
#    echo "                      master_id slave_id"
#    echo ""
#    echo "  Mode: 1 Prepare SBAS file (intf.tab scene.tab)"
#    echo "        2 run SBAS"
#    echo ""
#    exit 1
#fi

# use data.tab on intf_all path

if [ $# -eq 0 ]; then
    echo
    echo "Usage: process_stack.sh config_file [supermaster]"  
    echo
elif [ ! -f $1 ]; then
    echo
    echo "Cannot open $1. Please provide a valid config file."
    echo
else

    echo
    echo "- - - - - - - - - - - - - - - - - - - -"
    echo " Starting SBAS processing ..."
    echo "- - - - - - - - - - - - - - - - - - - -"
    echo

    config_file=$1
    source $config_file
    echo "Config file: $config_file"

    OSARIS_PATH=$( pwd )
    echo "GSP directory: $OSARIS_PATH"

    work_PATH=$base_PATH/$prefix/Processing
    # Path to working directory

    output_PATH=$base_PATH/$prefix/Output
    # Path to directory where all output will be written

    log_PATH=$base_PATH/$prefix/Output/Log
    # Path to directory where the log files will be written    
    
    

    mode=$2
    echo "mode -->" $mode

    if [ $mode -eq 1 ]; then

	cd $work_PATH	
	rm -rf SBAS
	mkdir SBAS
	
	cd $work_PATH/intf_all
	folders=($( ls -d */ ))
	for folder in "${folders[@]}"; do
	    master=${folder:0:7}
	    slave=${folder:8:7}
	    
	    cd $work_PATH/intf_all/"$master"_"$slave"

	    echo
	    echo "Now working on folder:"
	    pwd
	    echo
	    
	    # shopt -s extglob
	    # IFS=" "
	    
	    
	    #rm unwrap.grd
	    
	    #crop corr.grd to match with unwrap.grd
	    # region=$(grep region_cut ../../batch_tops.config | awk '{print $3}')
	    # gmt grdcut corr.grd -Gcorr_crop.grd -R$region -V
	    
	    #ls *.PRM > tmp2
	    #master_prm=$(head -n 1 tmp2)
	    #slave_prm=$(head -n 2 tmp2 | tail -n 1)
	    
	    #echo $master_prm $slave_prm > tmp

	    PRM_filelist=($(ls -v *.PRM))
	    echo
	    echo "PRM files: "
	    echo "$PRM_filelist[0] - $PRM_files[1]"
	    echo

	    for PRM_file in "${PRM_filelist[@]}"; do

	
		PRM_id=$(grep SC_clock_start $PRM_file | awk '{printf("%d",int($3))}')

		if [ "$PRM_id" == "$master" ]; then
		    master_PRM=$PRM_file
		    echo "Found master PRM file for id $PRM_id: $master_PRM"
		elif [ "$PRM_id" == "$slave" ]; then
		    slave_PRM=$PRM_file
		    echo "Found slave PRM file for id $PRM_id: $slave_PRM"
		else
		    echo "Warning: no fitting PRM file found for $PRM_id!"
		fi		    		
		#cp -a $PRM_file ../intf_all/${PRM_id}.PRM
		#cp $PRM_file ../intf_all/$PRM_id.PRM
	    done

	    SAT_baseline $work_PATH/intf_all/"$master"_"$slave"/$master_PRM $work_PATH/intf_all/"$master"_"$slave"/$slave_PRM > tmp
	   
	    BPL=$(grep B_perpendicular tmp | awk '{print $3}')
	    # rm tmp*
	    
	    #make intf.tab file
	    cd $work_PATH/SBAS
	    echo $work_PATH/intf_all/"$master"_"$slave"/unwrap.grd $work_PATH/intf_all/"$master"_"$slave"/corr.grd $master $slave $BPL >> intf.tab
	    ln -s $work_PATH/intf_all/"$master"_"$slave"/unwrap.grd .	   
	done
	
	cd $work_PATH/SBAS
	#make scene.tab file
	awk '{print int($2),$3}' $work_PATH/intf_all/baseline_table.dat >> scene.tab	
    fi

    if [ $mode -eq 2 ]; then
	cd $work_PATH/SBAS
	xdim=$(gmt grdinfo -C unwrap.grd | awk '{print $10}')
	ydim=$(gmt grdinfo -C unwrap.grd | awk '{print $11}')
	n_int=$(wc -l < intf.tab)
	n_scn=$(wc -l < scene.tab)
	#run SBAS
	sbas intf.tab scene.tab $n_int $n_scn $xdim $ydim -smooth 1.0 -wavelength 0.0554658 -incidence 30 -range 800184.946186 -rms -dem
	
	# project the velocity to Geocooridnates
	#
	ln -s ../topo/trans.dat .
	proj_ra2ll.csh trans.dat vel.grd vel_ll.grd
	gmt grd2cpt vel_ll.grd -T= -Z -Cjet > vel_ll.cpt
	grd2kml.csh vel_ll vel_ll.cpt
	
	# view disp.grd
	rm *.jpg *.ps disp.tab
	ls disp_0* > disp.tab
	
	shopt -s extglob
	IFS=" "
	while read disp;
	do
	    gambar="$disp".ps
	    gmt grdimage $disp -Cvel_ll.cpt -JX6i -Bx1000 -By250 -BWeSn -P -K > $gambar
	    gmt psscale -D1.3c/-1.2c/5c/0.2h -Cvel_ll.cpt -B30:"LOS displacement, mm":/:"range decrease": -P -J -R -O -X4 -Y20 >> $gambar
	    
	    ps2raster $gambar -Tj -E100
	    #echo $disp
	done < disp.tab
	
    fi
fi
