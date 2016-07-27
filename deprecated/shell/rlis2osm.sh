#!/usr/bin/env bash
# Convert RLIS streets and trails into .osm format so that it can be
# used as an aid in editing osm

# Set postgres parameters
DBNAME=rlis2osm
HOST=localhost
USER=postgres

# prompt the user to enter their postgres password if it is not set
if [ -z "${PGPASSWORD}" ]; then
    read -s -p 'Enter PostGreSQL password:' PGPASSWORD
    export PGPASSWORD
fi

# Set workspaces and project global project variables
RLIS_DIR='G:/Rlis'
CODE_DIR='G:/PUBLIC/OpenStreetMap/rlis2osm'
EXPORT_DIR='G:/PUBLIC/OpenStreetMap/data/RLIS_osm'
OGR2OSM_DIR='P:/ogr2osm'

OSPN=2913
STREETS_SHP="${RLIS_DIR}/STREETS/streets.shp"
TRAILS_SHP="${RLIS_DIR}/TRANSIT/trails.shp"

create_postgis_db() {
    # Create new Db (drop if already exists)
    dropdb -h "${HOST}" -U "${USER}" --if-exists "${DBNAME}"
    createdb -O "${USER}" -h "${HOST}" -U "${USER}" "${DBNAME}"

    # spatially enable the Db
    postgis_cmd='CREATE EXTENSION postgis;'
    psql -d "${DBNAME}" -h "${HOST}" -U "${USER}" -c "${postgis_cmd}"
}

load_rlis_shapefiles() {
    # Load rlis streets and trails into new postgis db
    shp2pgsql -s "${OSPN}" -D -I "${STREETS_SHP}" 'rlis_streets' \
        | psql -q -h "${HOST}" -U "${USER}" -d "${DBNAME}"

    shp2pgsql -s "${OSPN}" -D -I -W 'LATIN1' "${TRAILS_SHP}" 'rlis_trails' \
        | psql -q -h "${HOST}" -U "${USER}" -d "${DBNAME}"
}

execute_attribute_conversion() {
    # Run scripts that convert attributes to OSM nomenclature for
    # streets and trails

    # create function that converts postgres strings to tile case,
    # since it's a database object it will then be able to be called by
    # any subsequent script
    titlecase_sql="${CODE_DIR}/postgisql/string2titlecase.sql"
    psql -q -h "${HOST}" -d "${DBNAME}" -U "${USER}" -f "${titlecase_sql}"

    echo "Street attribute conversion beginning, start time is: $(date +'%r')"
    streets_sql="${CODE_DIR}/postgisql/rlis_streets2osm.sql"
    psql -q -h "${HOST}" -d "${DBNAME}" -U "${USER}" -f "${streets_sql}"

    echo "Trail attribute conversion beginning, start time is: $(date +'%r')"
    trails_sql="${CODE_DIR}/postgisql/rlis_trails2osm.sql"
    psql -q -h "${HOST}" -d "${DBNAME}" -U "${USER}" -f "${trails_sql}"
}

create_export_folder() {
    # Get the last modified date in yyyy_mm format from the rlis streets
    # shapefile and make a sub-folder in the export direct with that name
    mod_date="$(date -r "${STREETS_SHP}" +'%Y_%m')"
    cur_export="${EXPORT_DIR}/${mod_date}"
    mkdir -p "${cur_export}"
}

pgsql2osm() {
    # Export translated rlis data in postgres db to osm spatial format
    # using ogr2osm

    # my system python doesn't have the postgis driver for gdal so I
    # using the arcgis version of python that has this, but the
    # GDAL_DATA environment variable must also be reset
    arcpy_dir='C:/Python27/ArcGIS10.3'
    export GDAL_DATA="${arcpy_dir}/Lib/site-packages/osgeo/data/gdal"

    # create target folder for osm files that reflects rlis files'
    # release date
    create_export_folder

    # create string that establishes connection to postgresql db
    ogr2osm="${CODE_DIR}/bin/ogr2osm"
    pgsql_str="PG:dbname=${DBNAME} user=${USER}
        host=${HOST} password=${PGPASSWORD}"

    # a sql query is needed to export specific data from the postgres
    # db, if not supplied all data from the named db will be exported
    streets_tbl='osm_streets'
    streets_sql="SELECT * FROM ${streets_tbl}"
    rlis_streets_osm="${cur_export}/rlis_streets.osm"
    streets_trans="${CODE_DIR}/rlis2osm/streets_translation.py"

    "${ogr2osm}" -e "${OSPN}" -f -o "${rlis_streets_osm}" \
        -t "${streets_trans}" --sql "${streets_sql}" "${pgsql_str}"

    trails_tbl='osm_trails'
    trails_sql="SELECT * FROM ${trails_tbl}"
    rlis_trails_osm="${cur_export}/rlis_trails.osm"
    trails_trans="${CODE_DIR}/rlis2osm/trails_translation.py"

    "${ogr2osm}" -e "${OSPN}" -f -o "${rlis_trails_osm}" \
        -t "${trails_trans}" --sql "${trails_sql}" "${pgsql_str}"
}

main() {
    echo "rlis to OpenStreetMap conversion beginning,"
    echo "start time is: $( date +'%r' )"

#    create_postgis_db
#    load_rlis_shapefiles
#    execute_attribute_conversion
    pgsql2osm

    echo 'rlis to osm conversion completed,'
    echo "end time is: $( date +'%r' )"
}

main
