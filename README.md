# OSARIS
### Open Source SAR Investigation System
OSARIS provides a framework to process large stack of synthetic aperture radar (SAR) data in High Performance Computing (HPC) environments.

### REQUIREMENTS:
1. A working installation of GMT5SAR, further info and installation instructions at
   http://gmt.soest.hawaii.edu/projects/gmt5sar/wiki
2. A working SLURM environment, further info and installation instructions at
   https://slurm.schedmd.com/   

### DOWNLOAD / INSTALLATION
Clone the OSARIS repository:
git clone https://github.com/cryotools/osaris.git

### PREPARATION
- In the S1PPC folder, copy configuration templates to config folder
> cp ./templates/config.template ./config/_my_study_.cfg
> cp ./templates/GMTSAR.template ./config/GMTSAR_my_study_.cfg

- Edit new config files to fit your needs and local configuration.
  See comments for details.

- Make sure .sh files are executable (chmod +x <filename>)

...


### LAUNCH

