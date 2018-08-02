Changelog
All notable changes to this OSARIS will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- Module "GACOS correction" to correct interferograms for atmospheric disturbances

### Changed
- Renamed module "Homogenize Interferograms" to "Harmonize Interferogram Time Series"
- Renamed module "Simple Persistant Scatterer Identification" to "Stable Ground Point Identification"


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
