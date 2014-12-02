::Convert RLIS streets and trails into .osm format so that it can be used as an aid in editing osm
@echo off
setlocal EnableDelayedExpansion

::Set postgres parameters
set db_name=rlis2osm
set pg_host=localhost
set pg_user=postgres

::Prompt the user to enter their postgres password, 'pgpassword' is a keyword and will automatically
::set the password for most postgres commands in the current session
set /p pgpassword="Enter postgres password:"

::Set workspaces and project global project variables
set rlis_workspace=G:\Rlis
set code_workspace=G:\PUBLIC\OpenStreetMap\rlis2osm
set export_workspace=G:\PUBLIC\OpenStreetMap\data\RLIS_osm

set or_spn=2913
set rlis_streets_shp=%rlis_workspace%\STREETS\streets.shp
set rlis_trails_shp=%rlis_workspace%\TRANSIT\trails.shp

call:createPostgisDb
call:loadRlisShapefiles
call:executeAttributeConversion
call:createExportFolder
call:export2osm

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
set tcase_script=%code_workspace%\postgis\string2titlecase.sql
psql -q -h %pg_host% -d %db_name% -U %pg_user% -f %tcase_script%

echo "Street attribute conversion beginning, start time is: %time:~0,8%"
set streets_script=%code_workspace%\postgis\rlis_streets2osm.sql
psql -q -h %pg_host% -d %db_name% -U %pg_user% -f %streets_script%

echo "Trail attribute conversion beginning, start time is: %time:~0,8%"
set trails_script=%code_workspace%\postgis\rlis_trails2osm.sql
::psql -q -h %pg_host% -d %db_name% -U %pg_user% -f %trails_script%

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
set current_export=%export_workspace%\%mod_yr_mon%
if not exist %current_export% mkdir %current_export%

goto:eof


:export2osm
::Export converted streets and trails to .osm format

::ogr2osm which will be used to get the data into .osm format requires gdal with python bindings,
::at this time it is easiest for me to access the version of of gdal that I have with this add-on
::via the OSGeo4W Shell.  Thus that shell needs to be called
set osgeo4w_shell=C:\OSGeo4W64\OSGeo4W.bat
set rlis_ogr2osm=G:\PUBLIC\OpenStreetMap\rlis2osm\rlis_ogr2osm.bat

::the last seven variables called are parameters passed to the osgeo4w batch file
start %osgeo4w_shell% call %rlis_ogr2osm% %db_name% %pg_host% ^
	%pg_user% %pgpassword% %code_workspace% %current_export% %or_spn%

goto:eof