::Convert RLIS streets shapefile which has had its attributes translated to OSM nomenclature
::to .osm format so that it can be used as an editing aid
@echo off
setlocal EnableDelayedExpansion

::Assign parameters passed to this file to variables with descriptive names
set rlis_proj=%1
set export_workspace=%2
set streets_shp_mod=%3
set trails_shp_mod=%4

::ogr2osm is the tool that converts data between the shp and .osm formats, assign that tool
::and supplemental imputs around that tool to varibles
set ogr2osm_workspace=P:\ogr2osm

set ogr2osm_command=%ogr2osm_workspace%\ogr2osm.py
set streets_trans=%ogr2osm_workspace%\translations\rlis_streets_trans.py
set trails_trans=%ogr2osm_workspace%\translations\rlis_trails_trans.py

::Output locations of resultant datasets 
set streets_osm=%export_workspace%\rlis_streets.osm
set trails_osm=%export_workspace%\rlis_trails.osm

::Run the conversion tool
python %ogr2osm_command% -f -e %rlis_proj% -o %streets_osm% -t %streets_trans% %streets_shp_mod%
python %ogr2osm_command% -f -e %rlis_proj% -o %trails_osm% -t %trails_trans% %trails_shp_mod%

echo "rlis to osm conversion completed"
echo "end time is: %time%"