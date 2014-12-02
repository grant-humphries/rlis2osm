::Convert RLIS streets shapefile which has had its attributes translated to OSM nomenclature
::to .osm format so that it can be used as an editing aid
@echo off
setlocal EnableDelayedExpansion

::Assign parameters passed to this file to variables with descriptive names
set db_name=%1
set pg_host=%2
set pg_user=%3
set pgpassword=%4
set code_workspace=%5
set current_export=%6
set or_spn=%7

::Set ogr2osm variables, see paramaters, etc. for ogr2osm tool here:
::https://github.com/pnorman/ogr2osm/blob/master/Readme.md
set ogr2osm_workspace=P:\ogr2osm
set ogr2osm_cmd=%ogr2osm_workspace%\ogr2osm.py
set streets_trans=%code_workspace%\ogr2osm\rlis_streets_trans.py
set trails_trans=%code_workspace%\ogr2osm\rlis_trails_trans.py

::Set dataset variables
set streets_tbl=osm_streets
set rlis_streets_osm=%current_export%\rlis_streets.osm
set osm_streets_shp=%shp_export%\rlis_osm_streets.shp

set trails_tbl=osm_trails
set rlis_trails_osm=%current_export%\rlis_trails.osm
set osm_trails_shp=%shp_export%\rlis_osm_trails.shp

call:shp2osm
::call:pgsql2osm

echo "rlis to osm conversion completed"
echo "end time is: %time:~0,8%"

goto:eof


::-------------------------------------------
::Function section begins here

:pgsql2osm
::The functionality of converting pgsql data to osm has not quite yet been implemented,
::a pull request that will do this has been submitted, but not yet accepted, see the 
::following ticket to track progress: https://github.com/pnorman/ogr2osm/pull/29

set st_sql_param="SELECT * FROM %streets_tbl%"
set st_pgsql_string=PG:dbname=%db_name% user=%pg_user% host=%pg_host% --sql %st_sql_param%
python %ogr2osm_cmd% -e %or_spn% -f -o %rlis_streets_osm% ^
	-t %streets_trans% %st_pgsql_string%

set tr_sql_param="SELECT * FROM %trails_tbl%"
set tr_pgsql_string=PG:dbname=%db_name% user=%pg_user% host=%pg_host% --sql %tr_sql_param%
python %ogr2osm_cmd% -e %or_spn% -f -o %rlis_streets_osm% ^
	-t %streets_trans% %tr_pgsql_string%

goto:eof


:export2shp
::Export rlis streets, which have had their attributes and geometry modified to suit
::osm, back into shapefile format

::create folder for exported shapefiles
set shp_export=%current_export%\shp
if not exist %shp_export% mkdir %shp_export%

::export the converted streets and trails back to shapefile
::-k parameter retains case of field names (will be all caps otherwise)
pgsql2shp -k -h %pg_host% -u %pg_user% -P %pgpassword% ^
	-f %osm_streets_shp% %db_name% %streets_tbl%

::pgsql2shp -k -h %pg_host% -u %pg_user% -P %pgpassword% ^
::	-f %osm_trails_shp% %db_name% %trails_tbl%

goto:eof


:shp2osm
::Convert rlis-osm shapefiles into .osm spatial data format

::convert pgsql data into shapefiles
call:export2shp

::Convert shapefiles into osm data, the -e parameter indicates the spatial reference
::of the input data (output is always wgs84), -f overwrites any existing data, -t is
::the transaltion files that modifies attributes
python %ogr2osm_cmd% -e %or_spn% -f -o %rlis_streets_osm% ^
	-t %streets_trans% %osm_streets_shp%

python %ogr2osm_cmd% -e %or_spn% -f -o %rlis_trails_osm% ^
	-t %trails_trans% %osm_trails_shp%

goto:eof