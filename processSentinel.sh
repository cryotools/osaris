#!/bin/bash

echo "- - - - - - - - - - - - - - - - - - - -"
echo "Starting Sentinel data processing ..."
echo "- - - - - - - - - - - - - - - - - - - -"

# 1 - start from preprocess
# 2 - start from align SLC images
# 3 - start from make topo_ra 
# 4 - start from make and filter interferograms 
# 5 - start from unwrap phase
# 6 - start from geocode  

# If you are starting from SLC, the script align_tops.csh and p2p_S1A_TOPS.csh should help. For large stacks of data, try preproc_batch_tops.csh and intf_tops.csh


# align_tops.csh s1a-iw1-slc-vv-20150526t014935-20150526t015000-006086-007e23-001 S1A_OPER_AUX_POEORB_OPOD_20150615T155109_V20150525T225944_20150527T005944.EOF.txt s1a-iw1-slc-vv-20150607t014936-20150607t015001-006261-00832e-004 S1A_OPER_AUX_POEORB_OPOD_20150627T155155_V20150606T225944_20150608T005944.EOF.txt dem.grd 
# align_tops.csh s1a-iw2-slc-vv-20150526t014936-20150526t015001-006086-007e23-002 S1A_OPER_AUX_POEORB_OPOD_20150615T155109_V20150525T225944_20150527T005944.EOF.txt s1a-iw2-slc-vv-20150607t014936-20150607t015002-006261-00832e-005 S1A_OPER_AUX_POEORB_OPOD_20150627T155155_V20150606T225944_20150608T005944.EOF.txt dem.grd 
# align_tops.csh s1a-iw3-slc-vv-20150526t014937-20150526t015002-006086-007e23-003 S1A_OPER_AUX_POEORB_OPOD_20150615T155109_V20150525T225944_20150527T005944.EOF.txt s1a-iw3-slc-vv-20150607t014937-20150607t015003-006261-00832e-006 S1A_OPER_AUX_POEORB_OPOD_20150627T155155_V20150606T225944_20150608T005944.EOF.txt dem.grd 
