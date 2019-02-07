![OSARIS](https://cryo-tools.org/wp-content/uploads/2019/01/OSARIS-logo-600px.png)

### Open Source SAR Investigation System
OSARIS provides a framework to process large stacks of [Sentinel-1](http://www.esa.int/Our_Activities/Observing_the_Earth/Copernicus/Sentinel-1/Introducing_Sentinel-1) Synthetic Aperture Radar (SAR) data in High Performance Computing (HPC) environments.

## Table of Contents
* [Introduction](#introduction)
* [Setup](#setup)
  * [Requirements](#requirements) 
  * [Installation](#installation)
  * [Initial configuration](#initial-configuration)
  * [Launch](#launch)
* [Tutorial](#tutorial)
* [Tipps](#tipps)
* [Modules](#modules)
  * [Concept](#module-concept)
  * [Available modules](#available-modules)
  * [Module development](#module-development)
  * [Pre-defined variables](#pre-defined-variables)
* [Contributing](#contributing)
* [Crediting OSARIS](#crediting)
* [Credits / Contributors](#credits-contributors)

## <a name="introduction"></a> Introduction
With the advent of the two Sentinel 1 satellites, high-quality Synthetic Aperture Radar (SAR) data with high temporal and spatial resolution became freely available. This provides a promising framework to facilitate broad applications of detailed SAR- and interferometry- based surface change and motion timeseries. OSARIS aims to provide a toolkit to process large stacks of SAR secenes in parallel on HPC clusters to foster analysis of such extensive datasets. The idea behind OSARIS is to join the benefits of high-performance C programs with parallelization, flexibile processing schemes, and straight-forward configuration, by combining GMTSAR with the workload manager Slurm in a shell-script-based open and modular system.

Key features of OSARIS are:
- Convenient configuration (only one main config file, documented templates for all configuration)
- Modular structure for flexible processing schemes, modules for a variety of tasks readily available
- Minimalist software requirements (bash, csh, GMT, GMTSAR, Slurm)
- Automatic download of relevant Sentinel-1 scenes based on area of interest (AOI) and time interval
- Automatic download and assignment of orbits
- Merging of multiple swaths
- Merging of bursts from multiple slices, omission of bursts that are outside the AOI
- Single-master and pair-wise processing schemes
- Clear and simple directory structure and file naming
- Output files in the form of analysis-ready geocoded stacks of grid files, optionally cut to AOI extent
- Processing time measurements (wall clock versus total processing time)
- Detailed report and log files
- Summary PDF showing key processing results for each time step (see module Summary PDF)


## <a name="setup"></a> Setup

### <a name="requirements"></a> Requirements
1. A working installation of [GMTSAR](http://gmt.soest.hawaii.edu/projects/gmt5sar/wiki)
2. A working SLURM environment, further info and installation instructions at
   https://slurm.schedmd.com/   
3. [ImageMagick](https://www.imagemagick.org/script/index.php) (optional, required only by the 'Summary PDF' module) 

### <a name="installation"></a> Installation
Just clone the OSARIS repository to your machine:
```console
git clone https://github.com/cryotools/osaris.git
```

### <a name="initial-configuration"></a> Initial configuration
- Provide DEM data. You may use the [DEM generator](http://topex.ucsd.edu/gmtsar/demgen/) kindly provided by Scripps Institution of Oceanography at the University of California, San Diego.
  
- In the OSARIS folder, copy configuration templates to config folder
```console
cp ./templates/config.template ./config/*<my_study>*.config
cp ./templates/GMTSAR.template ./config/*<GMTSAR_my_study>*.config
```
- Edit new config files to fit your needs and local configuration.
  See comments in template files for details.

- Make sure .sh files in root and lib directories are executable. If not, use
```console
chmod +x <filename>
```

### <a name="launch"></a> Launch
Go to the OSARIS folder. Launch your run with
```console
./osaris.sh ./config/<my_config>.config
```

## <a name="tutorial"></a> Tutorial
If you are new to Sentinel-1 processing, take a look at the [OSARIS Tutorial at CryoTools.org](https://cryo-tools.org/tools/osaris/osaris-tutorial-1/) that will guide you through an example, starting from the very basics of finding data.

## <a name="tipps"></a> Tipps
- Launch OSARIS from within a [tmux](https://github.com/tmux/tmux/wiki) or [screen](https://www.gnu.org/software/screen/) session to detach your terminal session from the process. Doing this will prevent the OSARIS processing to fail in case you lose connection, your terminal crashes, etc. Tmux' feature to arrange multiple windows and panes is extremely handy to monitor log files during processing (see below).

- Start with relatively few scenes and a minimum of modules. Check the output and optimize your configuration. When the basic processing results fit your needs, use the options to turn off pre- and interferometric processing and start adding modules.

- Keep an eye on the log files during processing. In your procesing directory, use 
```console
tail -f Log/_logfile_name_
```
to monitor what is going on.

- After processing, take a look at the reports in 'Output/Reports'.

- Use the 'summary_pdf' module to get an overview of the interferometric processing results.

- Make sure the DEM extent is not much bigger than the extent of the scenes you actually want to process. A big DEM will need a lot of extra processing time.


## <a name="modules"></a> Modules
### <a name="concept"></a> Concept

Modules allow to execute additional processing routines at different stages, i.e. after file downloads, after file extraction, after GMTSAR processing, and after post-processing (more module hooks may be added in the future). As such, OSARIS modules facilitate designing processing schemes that fit individual needs while keeping the core code as compact as possible. 

In order to execute a module, go to the 'MODULES' section in the config file and put the module name (i.e. the name of the subdirectory of modules/) into the array of the adequate hook. For example, if you would like to execute 'Stable Ground Point Identification', 'Harmonize Grids', and 'Summary PDF' after GMTSAR interferometric processing, this would be:
```sh
post_processing_mods=( SGP_identification harmonize_grids summary_pdf )
```
When multiple modules are allocated at one hook the modules will be executed in the same order they appear in the array. 
Most modules require a config file; A template configuration should be in templates/modules-config which must be copied to the config directory for the module to work:
```console
mv templates/module-config/<module_name>.config.template config/<module_name>.config
```

### <a name="available-modules"></a> Available modules

#### Crop
Cut geocoded grids to extend given min/max longitude/latitude coordinates.
Call: crop
Status: beta

#### Displacement
Convert unwrapped phase (radians) to line-of-sight displacement (mm)
Call: displacement
Status: beta

#### Detrend
Remove large-scale trends from grid stacks using polynomial surfaces, cf. [GMT grdtrend](https://gmt.soest.hawaii.edu/doc/5.4.5/grdtrend.html).
Call: detrend
Status: beta

#### GACOS correction
Correct interferogram time series for atmospheric delays of the SAR signal using [GACOS](http://ceg-research.ncl.ac.uk/v2/gacos/) data.
Call: gacos_correction
Status: beta

#### Grid Difference
Calculate the difference between OSARIS result grid files throughout the timeseries.
Call: grid_difference
Status: beta

#### Harmonize Grids 
Shift grid files relative to 'stable ground points'. Typically used to harmonize time series of interferograms and LOS displacement files.
Call: harmonize_grids
Status: beta

#### Ping
Wake up sleeping nodes.
Call: ping
Status: beta

#### Stable Ground Point Identification
Identify stable ground points based on consitently high coherences throughout the time series.
Call: sgp_identification
Status: beta

#### Statistics
Calculate statistics for a series of grid files.
Call: statistics
Status: beta

#### Summary PDF
Preview key processing results in a single graphic overview. Requires ImageMagick.
Call: summary_pdf
Status: beta

#### Timeseries xy
Extract values for particular coordinates throughout a series of grids (e.g. coherence, phase). 
Call: timerseries_xy
Status: beta

#### Unstable Coherence Metric
Identify regions where high coherence values drop substantially between two data takes.
Call: unstable_coh_metric
Status: beta



### <a name="module-development"></a> Module development
The easiest way to get started developing your own OSAIRS module is by copying the template files prepared for this purpose:
```console
# In each line, replace <my_new_module> with your module name
cp -r modules/__module_template__ modules/<my_new_module>
mv modules/<my_new_module>/__module_template__.sh <my_new_module>.sh 
cp templates/module-config/__module_template.config.template config/<my_new_module>.config
```
Many typical processing steps are implemented in the existing modules, copy as much as you can. 
When your module works and you think it might be useful to others please get in touch or create a merge request from a forked copy.

### <a name="constants"> Constants you can use
The following constants will be set by the OSARIS main program upon initialization and are available in all modules that get included:

| Constant        | Value |
| --------------- | ----- |
| $OSARIS\_PATH   | Full path to the directory from which OSARIS was launched. |
| $work\_PATH     | Full path to the Processing directory. |
| $output\_PATH   | Full path to the Output directory. |
| $log\_PATH      | Full path to the Log directory. |
| $topo\_PATH     | Full path to directory with dem.grd used by GMTSAR. |
| $orbits\_PATH   | Full path to directory containing the orbit files. |

All values set in the main config file can be accessed by their respective variable name.


## <a name="contributing"></a> Contributing
Your participation in the development of OSARIS is strongly encouraged! In case you want to add a feature, module, etc., please fork your copy, code your additions, and open a merge request when finished. If you are using OSARIS, it would be very helpful if you could prepare a short report with general information about your OS and hardware setup and your experience with the software, so that we can evaluate compatibility over different configurations.
For all reports and inquiries please contact [David Loibl](https://hu.berlin/davidloibl).


## <a name="crediting"></a> Crediting OSARIS
As stated in the license file, you are free to use OSARIS in whatever way you like. If you publish OSARIS results, e.g. in scientific publications, please credit OSARIS using the Zenodo DOI:

[![DOI](https://zenodo.org/badge/108271075.svg)](https://zenodo.org/badge/latestdoi/108271075)


## <a name="credits-contributors"></a> Credits / Contributors
A (hopefully) full list of contributors is available in `doc/contributors.md` - Many thanks to all those who have contributed to make this a better tool. Many thanks to Bodo Bookhagen and Ziyadin Cakir who substantially supported the conception of OSARIS with thoughtful comments and by sharing scripts. 
The work of David Loibl on OSARIS was supported by the [Research Network Geo.X](https://www.geo-x.net/en/) during 2016-12 - 2017-12 within the scope of the project [MORSANAT](https://www.geographie.hu-berlin.de/en/professorships/climate_geography/research-2/climate-change-and-cryosphere-research/morsanat?set_language=en).