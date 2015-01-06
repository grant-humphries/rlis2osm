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
set shp_export=%current_export%\shp

set streets_tbl=osm_streets
set rlis_streets_osm=%current_export%\rlis_streets.osm
set osm_streets_shp=%shp_export%\rlis_osm_streets.shp

set trails_tbl=osm_trails
set rlis_trails_osm=%current_export%\rlis_trails.osm
set osm_trails_shp=%shp_export%\rlis_osm_trails.shp

call:pgsql2osm
::call:pgsql-shp2osm

echo "rlis to osm conversion completed"
echo "end time is: %time:~0,8%"

goto:eof


::-------------------------------------------
::Function section begins here

:pgsql2osm
::Export translated rlis data in postgres db to osm spatial format using ogr2osm

::create string that establishes connection to postgresql db
set pgsql_str="PG:dbname=%db_name% user=%pg_user% host=%pg_host%"

::a sql query is needed to export specific data from the postgres db, if
::not supplied all data from the named db will be exported
set streets_sql="SELECT * FROM %streets_tbl%"
python %ogr2osm_cmd% -e %or_spn% -f -o %rlis_streets_osm% ^
	-t %streets_trans% --sql %streets_sql% %pgsql_str%

set trails_sql="SELECT * FROM %trails_tbl%"
python %ogr2osm_cmd% -e %or_spn% -f -o %rlis_trails_osm% ^
	-t %trails_trans% --sql %trails_sql% %pgsql_str%

goto:eof


:export2shp
::Export osm-translated rlis data back into shapefile format

::create folder for exported shapefiles
if not exist %shp_export% mkdir %shp_export%

::export the converted streets and trails back to shapefile
::-k parameter retains case of field names (will be all caps otherwise)
pgsql2shp -k -h %pg_host% -u %pg_user% -P %pgpassword% ^
	-f %osm_streets_shp% %db_name% %streets_tbl%

pgsql2shp -k -h %pg_host% -u %pg_user% -P %pgpassword% ^
	-f %osm_trails_shp% %db_name% %trails_tbl%

goto:eof


:pgsql-shp2osm
::Convert osm data in postgres db to osm spatial format via shapefiles, now that
::ogr2osm allows direction conversion from pgsql to osm this is deprecated, but
::am keeping it around just in case

::convert pgsql data into shapefiles
call:export2shp

::Convert shapefiles into osm data, the -e parameter indicates the spatial reference
::of the input data (output is always wgs84), -f overwrites any existing data, -t is
::the translation file that modifies attributes
python %ogr2osm_cmd% -e %or_spn% -f -o %rlis_streets_osm% ^
	-t %streets_trans% %osm_streets_shp%

python %ogr2osm_cmd% -e %or_spn% -f -o %rlis_trails_osm% ^
	-t %trails_trans% %osm_trails_shp%

goto:eof