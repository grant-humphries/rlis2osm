#!/usr/bin/env bash

set -e

OSPN_EPSG=2913
PGDBNAME='rlis_abbr_test'
DATA_DIR="$( cd $(dirname ${0}); dirname $(pwd -P) )/data"
DATASETS=( 'streets' 'trails' )

process_options() {
    if [[ -z "${PGUSER}" ]]; then
        read -p $'Enter postgres user name:\n' PGUSER
    fi

    if [[ -z "${PGPASSWORD}" ]]; then
        nl=$'\n'
        read -s -p "Enter postgres password for user '${PGUSER}':${nl}" PGPASSWORD
        export PGPASSWORD
    fi
}

create_postgis_db() {
    # if the db exists do nothing
    # http://stackoverflow.com/questions/1454927
    
    if ! psql -lqtA -U "${PGUSER}" | grep -q "^${PGDBNAME}|"; then
        createdb -U "${PGUSER}" "${PGDBNAME}"
        psql -d "${PGDBNAME}" -U "${PGUSER}" -c 'CREATE EXTENSION postgis;'
    fi
}

load_data() {
    for ds in "${DATASETS[@]}"; do
        ds_path="${DATA_DIR}/${ds}.shp"

        if [[ ! -f "${ds_path}" ]]; then
            zip_path="${ds_path%.*}.zip"

            if [[ -f "${zip_path}" ]]; then
                unzip -o "${zip_path}" -d "${DATA_DIR}"
            else
                echo "file: ${ds_path} doesn't not exist, script can't proceed"
                exit 1
            fi
        fi

        shp2pgsql -d -s "${OSPN_EPSG}" -I -D $(cygpath -w "${ds_path}") \
            | psql -d "${PGDBNAME}" -U "${PGUSER}"
    done
}

abbr_search_tables() {
    :
}

process_options
create_postgis_db
load_data
#abbr_search_tables