#!/usr/bin/python

# Convert .meta4 XML-files to file list compatible with dhusget.sh

import sys
import xml.etree.ElementTree as ET
# import math as math
# from scipy.io.numpyio import fwrite, fread
# import os
# import numpy as np
# import pylab as py

if (len(sys.argv) > 1):

    input_file = open(sys.argv[1],'rb')
    output_file = sys.argv[2]

    tree = ET.parse(input_file) # '/data/scratch/loibldav/GSP/Input/Meta4/Bishkek-Golubin-2017-03-01.meta4'
    root = tree.getroot()
    
    # print root.tag
    # print root.attrib
    
    with open(output_file, "w") as text_file:
       for child in root:
          # print(child.attrib['name'][:-4])
          # print(child[1].text[53:-9])
          text_file.write(" x {0}".format(child[1].text[53:-9]))    
          text_file.write(" x {0}".format(child.attrib['name'][:-4]))
          text_file.write("\n")
         
else:
    print "Usage: meta4-to-filelist.py [input file (.meta4)] [output file]"


