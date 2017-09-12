# GMTSAR Sentinel processing chain README

### REQUIREMENTS:
1. ESA's "dhusget.sh" script (specify path in config.txt), further info at
   https://scihub.copernicus.eu/twiki/do/view/SciHubUserGuide/5APIsAndBatchScripting#dhusget_script
2. A working installation of GMT5SAR, further info and installation instructions at
   http://gmt.soest.hawaii.edu/projects/gmt5sar/wiki
3. A working installation of GIAnT, further info and installation instructions at
   http://earthdef.caltech.edu/projects/giant/wiki
   [optional, required for atmospheric corrections and SBAS]
4. A working SLURM environment, further info and installation instructions at
   https://slurm.schedmd.com/
   [optional, required for parallel processing]

### DOWNLOAD / INSTALLATION
Clone the S1PPC repository:
git clone ___repository_path___

### PREPARATION
- In the S1PPC folder, copy configuration templates to config folder
> cp ./templates/config.template ./config/_my_study_.cfg
> cp ./templates/GMTSAR.template ./config/GMTSAR_my_study_.cfg

- Edit new config files to fit your needs and local configuration.
  See comments for details.

- Make sure .sh files are executable (chmod +x <filename>)

...


### LAUNCH

