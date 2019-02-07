Changelog
All notable changes to this OSARIS will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).


## [0.7.2] - 2019-02-07
### Added
- Parallel processing option for Summary PDF Module
- Improved burst handling, now also stripping unused bursts in single slice configurations

### Bugs fixed
- Reporting in GACOS correction module
- File downloads


## [0.7.1] - 2019-01-28
### Bugs fixed
- File downloads


## [0.7.0] - 2019-01-25
### Added
- Functionality to merge multiple swaths
- Cutting of output files to an area of interest defined by boundary box coordinates in the config file
- Module 'GACOS Correction' to handle atmospheric disturbances
- Module 'Detrend' to remove large-scale trends
- Module 'Preview Files' generating PNGs and KMLs
- Tool to shift coordinates from 0/360 to -180/180 notation
- ASF as alternative provider for S1 orbits and scenes

### Changed
- Output directory structure: now containing only one directory per dataset without sub-directories
- Output file naming: now consistently beginning with scene dates in the format YYYYMMDD--YYYMMDD
- Renamed module 'Create Summary PDF' to 'Summary PDF' and modified to new directory structure and file names
- Renamed module 'Homogenize Intfs' to 'Harmonize Grids' and made it much more flexible
- Renamed module 'Simple PSI' to 'Stable Ground Point Identification'
- Moved login credentials to separate file (from main configuration file)


## [0.6.0] - 2018-04-18
### Added
- Module "Create PDF Summary" to generate a visual overview of key processing results
- Module "Crop" to crop grid files to a extent given by coordinates
- Module "Statistics" generatig statistics for grid files
- SNAPHU connected components as output file
- Directory "tools" for supplementary routines to be configured and run manually.
- Tool "pyStatisticPlots" to create box and whisker plots from output of the Statistics module
- Template for new modules
- Options to skip processing steps

### Changed
- lib/z_min_max.sh -> Parameter order
- File names of output files and directories consitently use master/slave dates first in YYYYMMDD format
- Module Simple PSI configuration to use only a sub-region
- Fixed hardcoded path bug in p2p script
- Fixed bugs in reverse pairs processing functionality


### Removed
- Directory /lib/inlcude. Scripts were moved to lib and modified to be called directly instead of being inlcuded.
