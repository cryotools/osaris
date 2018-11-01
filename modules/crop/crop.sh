#!/usr/bin/env bash

######################################################################
#
# OSARIS module to crop grid files.
#
# 
#
# David Loibl, 2018
#
#####################################################################

module_name="crop"

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
    
    crop_output_PATH=$output_PATH/Crop
    mkdir -p $crop_output_PATH

    for crop_region_label in ${crop_region_labels[@]}; do
	mkdir -p $crop_output_PATH/$crop_region_label
    done
    
    if [ -d $crop_input_PATH ]; then

	cd $crop_input_PATH

	if [ "$crop_subdirs" -eq 0 ]; then

	    # List and crop all files of specified

	    crop_files=($( ls $crop_input_filenames ))
	    crop_counter=0

	    for crop_file in ${crop_files[@]}; do
		crop_region_counter=0
		for crop_region in ${crop_region_labels[@]}; do
		    gmt grdcut $crop_file \
			-G$crop_output_PATH/$crop_region/crop_$crop_file \
			-R${crop_regions[$crop_region_counter]} -V
		    ((crop_region_counter++))
		done
		((crop_counter++))
	    done
	else
	    folders=($( ls -d */ ))
	    crop_counter=0
	    for folder in "${folders[@]}"; do           
		folder=${folder::-1}
		cd $folder

		echo "Now working in directory $folder ..."

		crop_files=($( ls $crop_input_filenames ))

		for crop_file in ${crop_files[@]}; do
		    echo "   Cropping $crop_file ..."
		    crop_region_counter=0
		    for crop_region in ${crop_region_labels[@]}; do
			echo "gmt grdcut $crop_file -G$crop_output_PATH/$crop_region/${folder}-${crop_file::-4}-crop.grd -R${crop_regions[$crop_region_counter]} -V"
			gmt grdcut $crop_file \
			    -G$crop_output_PATH/$crop_region/${folder}-${crop_file::-4}-crop.grd \
			    -R${crop_regions[$crop_region_counter]} -V
			((crop_region_counter++))
		    done
		    ((crop_counter++))
		done

		cd ..

	    done
	fi
    else
	echo; echo "Error: $crop_input_PATH does not exist."
	echo "Variable crop_input_PATH must be set to a valid directory in crop.config. Exiting crop module."; echo
    fi




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
