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
set script_workspace=G:\PUBLIC\OpenStreetMap\rlis2osm
set export_workspace=G:\PUBLIC\OpenStreetMap\data\RLIS_osm

set or_spn=2913
set rlis_streets_shp=%rlis_workspace%\STREETS\streets.shp
set rlis_trails_shp=%rlis_workspace%\TRANSIT\trails.shp

call:createPostgisDb
call:loadRlisShapefiles
call:executeAttributeConversion

goto:eof

::---------------------------
::Function section begins here

:createPostgisDb

::Create new Db (drop if already exists)
dropdb -h %pg_host% -U %pg_user% --if-exists -i %db_name%
createdb -O %pg_user% -h %pg_host% -U %pg_user% %db_name%

::Spatially enable the Db
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
set tcase_script=%script_workspace%\postgis\string2titlecase.sql
psql -q -h %pg_host% -d %db_name% -U %pg_user% -f %tcase_script%

echo "Street attribute conversion beginning, start time is: %time:~0,8%"
set streets_script=%script_workspace%\postgis\rlis_streets2osm.sql
psql -q -h %pg_host% -d %db_name% -U %pg_user% -f %streets_script%

echo "Trail attribute conversion beginning, start time is: %time:~0,8%"
set trails_script=%script_workspace%\postgis\rlis_trails2osm.sql
::psql -q -h %pg_host% -d %db_name% -U %pg_user% -f %trails_script%

goto:eof


:export2osm
::Export converted streets and trails to .osm format

::Get the last modified date from the rlis streets shapefile
for %%i in (%rlis_streets_shp%) do (
	rem appending '~t' in front of the variable name in a loop will return the time 
	rem and date that the file that was assigned to that variable was last modified
	set mod_date_time=%%~ti
	
	rem reformat the date such the it is in the following form YYYY_MM
	set mod_yr_mon=!mod_date_time:~6,4!_!mod_date_time:~0,2!
)

::Create a sub-folder in export directory based on the modified date
set current_export=%export_workspace%\%mod_yr_mon%
if not exist %current_export% mkdir %current_export%

::Convert the modified shapefiles to .osm format.  The code that will do this must be run in the 
::OSGeo4W Shell.  Thus that shell is launched below and a batch file containing that code is run
::there and parameters needed from this file are passed to that script
set osgeo4w_shell=C:\OSGeo4W64\OSGeo4W.bat
set pgsql2osm_script=G:\PUBLIC\OpenStreetMap\rlis2osm\rlis_shp2rlis_dot_osm.bat

::The last six variables called are parameters passed to the osgeo4w batch file
start %osgeo4w_shell% call %pgsql2osm_script% %or_spn% %current_export% ^
	%db_name% %pg_host% %pg_user% %pgpassword%

goto:eof




set shp_export=%export_workspace%\shp
if not exist %shp_export% mkdir %shp_export%

::Export the modified streets and trails back to shapefile
set streets_shp_mod=%shp_export%\rlis_osm_streets.shp
set trails_shp_mod=%shp_export%\rlis_osm_trails.shp

pgsql2shp -k -h %pg_host% -u %pg_user% -P %pgpassword% -f %streets_shp_mod% %db_name% osm_streets_final
pgsql2shp -k -h %pg_host% -u %pg_user% -P %pgpassword% -f %trails_shp_mod% %db_name% osm_trails_final
