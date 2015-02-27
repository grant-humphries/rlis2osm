::Convert RLIS streets and trails into .osm format so that it can be used as an aid in editing osm
@echo off
setlocal EnableDelayedExpansion

echo "rlis to osm conversion beginning"
echo "start time is: %time:~0,8%"

::Set postgres parameters
set db_name=rlis2osm
set pg_host=localhost
set pg_user=postgres

::Prompt the user to enter their postgres password, 'pgpassword' is a keyword and will automatically
::set the password for most postgres commands in the current session
set /p pgpassword="Enter postgres password:"

::Set dirs and project global project variables
set rlis_dir=G:\Rlis
set code_dir=G:\PUBLIC\OpenStreetMap\rlis2osm
set export_dir=G:\PUBLIC\OpenStreetMap\data\RLIS_osm
set ogr2osm_dir=P:\ogr2osm

set or_spn=2913
set rlis_streets_shp=%rlis_dir%\STREETS\streets.shp
set rlis_trails_shp=%rlis_dir%\TRANSIT\trails.shp

call:createPostgisDb
call:loadRlisShapefiles
call:executeAttributeConversion
call:createExportFolder
call:pgsql2osm

echo "rlis to osm conversion completed"
echo "end time is: %time:~0,8%"

goto:eof


::-------------------------------------------
::Function section begins here

:createPostgisDb

::Create new Db (drop if already exists)
dropdb -h %pg_host% -U %pg_user% --if-exists -i %db_name%
createdb -O %pg_user% -h %pg_host% -U %pg_user% %db_name%

::spatially enable the Db
set pgis_q="CREATE EXTENSION postgis;"
psql -d %db_name% -h %pg_host% -U %pg_user% -c %pgis_q%

goto:eof


:loadRlisShapefiles
::Load rlis streets and trails into new postgis Db

shp2pgsql -s %or_spn% -D -I %rlis_streets_shp% rlis_streets ^
	| psql -q -h %pg_host% -U %pg_user% -d %db_name%

shp2pgsql -s %or_spn% -D -I %rlis_trails_shp% rlis_trails ^
	| psql -q -h %pg_host% -U %pg_user% -d %db_name%

goto:eof


:executeAttributeConversion
::Run scripts that convert attributes to OSM nomenclature for streets and trails

::create function that converts postgres strings to tile case, since it's a
::database object it will then be able to be called by any subsequent script
set tcase_script=%code_dir%\postgis\string2titlecase.sql
psql -q -h %pg_host% -d %db_name% -U %pg_user% -f %tcase_script%

echo "Street attribute conversion beginning, start time is: %time:~0,8%"
set streets_script=%code_dir%\postgis\rlis_streets2osm.sql
psql -q -h %pg_host% -d %db_name% -U %pg_user% -f %streets_script%

echo "Trail attribute conversion beginning, start time is: %time:~0,8%"
set trails_script=%code_dir%\postgis\rlis_trails2osm.sql
psql -q -h %pg_host% -d %db_name% -U %pg_user% -f %trails_script%

goto:eof


:createExportFolder
::Create target folder for output osm files that reflects source rlis 
::files' release date

::Get the last modified date from the rlis streets shapefile
for %%i in (%rlis_streets_shp%) do (
	rem appending '~t' in front of the variable name in a loop will return the time 
	rem and date that the file that was assigned to that variable was last modified
	set mod_date_time=%%~ti
	
	rem reformat the date such the it is in the following form YYYY_MM
	set mod_yr_mon=!mod_date_time:~6,4!_!mod_date_time:~0,2!
)

::create a sub-folder in export directory based on the modified date
set current_export=%export_dir%\%mod_yr_mon%
if not exist %current_export% mkdir %current_export%

goto:eof


:pgsql2osm
::Export translated rlis data in postgres db to osm spatial format using ogr2osm

::create string that establishes connection to postgresql db
set ogr2osm=%ogr2osm_dir%\ogr2osm.py
set pgsql_str="PG:dbname=%db_name% user=%pg_user% host=%pg_host%"

::a sql query is needed to export specific data from the postgres db, if
::not supplied all data from the named db will be exported
set streets_tbl=osm_streets
set streets_sql="SELECT * FROM %streets_tbl%"
set rlis_streets_osm=%current_export%\rlis_streets.osm
set streets_trans=%code_dir%\ogr2osm\rlis_streets_trans.py
python %ogr2osm% -e %or_spn% -f -o %rlis_streets_osm% ^
	-t %streets_trans% --sql %streets_sql% %pgsql_str%

set trails_tbl=osm_trails
set trails_sql="SELECT * FROM %trails_tbl%"
set rlis_trails_osm=%current_export%\rlis_trails.osm
set trails_trans=%code_dir%\ogr2osm\rlis_trails_trans.py
python %ogr2osm% -e %or_spn% -f -o %rlis_trails_osm% ^
	-t %trails_trans% --sql %trails_sql% %pgsql_str%

goto:eof