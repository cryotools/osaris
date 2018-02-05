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
- Provide DEM data. You may use the DEM generator: 
  http://topex.ucsd.edu/gmtsar/demgen/

- In the OSARIS folder, copy configuration templates to config folder
> cp ./templates/config.template ./config/_my_study_.config
> cp ./templates/GMTSAR.template ./config/GMTSAR_my_study_.config

- Edit new config files to fit your needs and local configuration.
  See comments in template files for details.

- Make sure .sh files are executable (chmod +x <filename>)


### LAUNCH
Go to the OSARIS folder. Launch your run with
./osaris.sh ./config/_my_config_.config


### MODULES
## Ping
Wake up sleeping nodes
Status: beta

## Prepare ArcticDEM
Prepare ArcticDEM tiles to be used as topo data in GMTSAR (merge, project).
Status: alpha

## Simple PSI
Identify persistent scatterers by finding data points of consitently high coherences.
Status: alpha

## Homogenize interferograms
Shift unwrapped interferograms and LOS relatively to 'stable ground points'.
Status: alpha

## Coherence diff
Calculate the difference between coherences.
Status: conceptual

## Unstable Coherence Metric
Identify regions where high coherence values drop substantially between two data takes.
Status: beta

## Timeseries xy
Extract values for particular coordinates throughout a series of grids (e.g. coherence, phase). 
Status: alpha


### GETTING INVOLVED
Your participation in the development of OSARIS is strongly encouraged! In case you want to add a feature, module, etc., please fork your copy, code your additions, and open a merge request when finished. If you are interested in joining the development team please get in touch: https://hu.berlin/davidloibl .


### CREDITING
As stated in the license file, you are free to use OSARIS in whatever way you like. If you publish OSARIS results, e.g. in scientific publications, please credit the website cryo-tools.org/tools/osaris .


### Acknowledgements
Thanks to Ziyadin Cakir who supported the conception of OSARIS with thoughtful comments and by sharing scripts.