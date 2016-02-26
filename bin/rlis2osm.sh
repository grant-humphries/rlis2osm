#!/usr/bin/env bash
# Convert RLIS streets and trails into .osm format so that it can be
# used as an aid in editing osm

echo "rlis to OpenStreetMap conversion beginning,"
echo "start time is: $(date +'%r')"

# Set postgres parameters
pg_dbname=rlis2osm
pg_host=localhost
pg_user=postgres

# prompt the user to enter their postgres password if it is not set
if [ -z "$PGPASSWORD" ]; then
    read -s -p "Enter PostGreSQL password:" PGPASSWORD
fi

# Set workspaces and project global project variables
rlis_dir="G:/Rlis"
code_dir="G:/PUBLIC/OpenStreetMap/rlis2osm"
export_dir="G:/PUBLIC/OpenStreetMap/data/RLIS_osm"
ogr2osm_dir="P:/ogr2osm"

or_spn=2913
rlis_streets_shp="${rlis_dir}/STREETS/streets.shp"
rlis_trails_shp="${rlis_dir}/TRANSIT/trails.shp"

createPostgisDb()
{
    # Create new Db (drop if already exists)
    dropdb -h $pg_host -U $pg_user --if-exists -i $pg_dbname
    createdb -O $pg_user -h $pg_host -U $pg_user $pg_dbname

    # spatially enable the Db
    pgis_q="CREATE EXTENSION postgis;"
    psql -d $pg_dbname -h $pg_host -U $pg_user -c "$pgis_q"
}

loadRlisShapefiles()
{
    # Load rlis streets and trails into new postgis Db
    shp2pgsql -s $or_spn -D -I $rlis_streets_shp rlis_streets \
        | psql -q -h $pg_host -U $pg_user -d $pg_dbname

    shp2pgsql -s $or_spn -D -I -W "LATIN1" $rlis_trails_shp rlis_trails \
        | psql -q -h $pg_host -U $pg_user -d $pg_dbname
}

executeAttributeConversion()
{
    # Run scripts that convert attributes to OSM nomenclature for
    # streets and trails

    # create function that converts postgres strings to tile case,
    # since it's a database object it will then be able to be called by
    # any subsequent script
    tcase_script="${code_dir}/postgis/string2titlecase.sql"
    psql -q -h $pg_host -d $pg_dbname -U $pg_user -f "$tcase_script"

    echo "Street attribute conversion beginning, start time is: $(date +'%r')"
    streets_script="${code_dir}/postgis/rlis_streets2osm.sql"
    psql -q -h $pg_host -d $pg_dbname -U $pg_user -f "$streets_script"

    echo "Trail attribute conversion beginning, start time is: $(date +'%r')"
    trails_script="${code_dir}/postgis/rlis_trails2osm.sql"
    psql -q -h $pg_host -d $pg_dbname -U $pg_user -f "$trails_script"
}

createExportFolder()
{
    # Get the last modified date in yyyy_mm format from the rlis streets
    # shapefile and make a sub-folder in the export direct with that name
    mod_date="$(date -r $rlis_streets_shp +'%Y_%m')"
    cur_export="${export_dir}/${mod_date}"
    mkdir -p $cur_export
}

pgsql2osm()
{
    # Export translated rlis data in postgres db to osm spatial format
    # using ogr2osm

    # my system python doesn't have the postgis driver for gdal so I
    # have to use another version of python that I have installed
    alt_py_dir='C:/Python27/ArcGIS10.3'
    arcpython="${alt_py_dir}/python"
    export GDAL_DATA="${alt_py_dir}/Lib/site-packages/osgeo/data/gdal"

    # create target folder for osm files that reflects rlis files'
    # release date
    createExportFolder;

    # create string that establishes connection to postgresql db
    ogr2osm="${ogr2osm_dir}/ogr2osm.py"
    pgsql_str="PG:dbname=${pg_dbname} user=${pg_user}
        host=${pg_host} password=${PGPASSWORD}"

    # a sql query is needed to export specific data from the postgres
    # db, if not supplied all data from the named db will be exported
    streets_tbl=osm_streets
    streets_sql="SELECT * FROM $streets_tbl"
    rlis_streets_osm="${cur_export}/rlis_streets.osm"
    streets_trans="${code_dir}/ogr2osm/rlis_streets_trans.py"

    $arcpython $ogr2osm -e $or_spn -f -o $rlis_streets_osm \
        -t $streets_trans --sql "$streets_sql" "$pgsql_str"

    trails_tbl=osm_trails
    trails_sql="SELECT * FROM $trails_tbl"
    rlis_trails_osm="${cur_export}/rlis_trails.osm"
    trails_trans="${code_dir}/ogr2osm/rlis_trails_trans.py"

    $arcpython $ogr2osm -e $or_spn -f -o $rlis_trails_osm \
        -t $trails_trans --sql "$trails_sql" "$pgsql_str"
}

createPostgisDb;
loadRlisShapefiles;
executeAttributeConversion;
pgsql2osm;

echo "rlis to osm conversion completed,"
echo "end time is: $(date +'%r')"                                                                                                                                             