::Convert RLIS streets shapefile which has had its attributes translated to OSM nomenclature
::to .osm format so that it can be used as an editing aid
@echo off
setlocal EnableDelayedExpansion

::Assign parameters passed to this file to variables with descriptive names
set or_spn=%1
set current_export=%2
set db_name=%3
set pg_host=%4
set pg_user=%5
set pgpassword=%6

::Set ogr2osm variables, see paramaters, etc. for ogr2osm tool here:
::https://github.com/pnorman/ogr2osm/blob/master/Readme.md
set ogr2osm_workspace=P:\ogr2osm
set ogr2osm_cmd=%ogr2osm_workspace%\ogr2osm.py
set streets_trans=%ogr2osm_workspace%\translations\rlis_streets_trans.py
set trails_trans=%ogr2osm_workspace%\translations\rlis_trails_trans.py

::Set dataset variables
set rlis_streets_osm=%current_export%\rlis_streets.osm
set rlis_trails_osm=%current_export%\rlis_trails.osm
set osm_streets_shp=%shp_export%\rlis_osm_streets.shp
set osm_trails_shp=%shp_export%\rlis_osm_trails.shp

call:shp2osm
::call:pgsql2osm

echo "rlis to osm conversion completed"
echo "end time is: %time:~0,8%"

goto:eof


::-------------------------------------------
::Function section begins here

:pgsql2osm
::https://github.com/pnorman/ogr2osm/pull/29

goto:eof


:export2shp
::Export rlis streets, which have had their attributes and geometry modified to suit
::osm, back into shapefile format

::create folder for exported shapefiles
set shp_export=%current_export%\shp
if not exist %shp_export% mkdir %shp_export%

::Export the converted streets and trails back to shapefile
::-k parameter retains case of field names (will be all caps otherwise)
set streets_tbl=osm_streets
pgsql2shp -k -h %pg_host% -u %pg_user% -P %pgpassword% -f %osm_streets_shp% %db_name% %streets_tbl%

set trails_tbl=osm_trails
::pgsql2shp -k -h %pg_host% -u %pg_user% -P %pgpassword% -f %osm_trails_shp% %db_name% %trails_tbl%

goto:eof


:shp2osm
::

call:export2shp

::Run the conversion tool
python %ogr2osm_cmd% -f -e %or_spn% -o %rlis_streets_osm% -t %streets_trans% %osm_streets_shp%
python %ogr2osm_cmd% -f -e %or_spn% -o %rlis_trails_osm% -t %trails_trans% %osm_trails_shp%

goto:eof