#!/usr/bin/env bash

set -e
shopt -s expand_aliases

PGDBNAME='rlis_abbr_test'
PGHOST='localhost'
PGCLIENTENCODING='UTF8'

ospn_espg=2913
project_dir="$( cd $(dirname ${0}); dirname $(dirname $(pwd -P)) )"

# cygwin-psql can't read file paths starting like '/cygdrive/...'
if [[ "${OSTYPE}" == 'cygwin' ]]; then
    project_dir="$( cygpath -w ${project_dir} )"
fi

# process command line options
while getopts ':p:u:' opt; do
    case "${opt}" in
        p)
            PGPASSWORD="${OPTARG}"
            ;;
        u)
            PGUSER="${OPTARG}"
            ;;
        d)
            data_dir="${OPTARG}"
            ;;
    esac
done

# if user doesn't supply postgres username and password prompt them
if [[ -z "${PGUSER}" ]]; then
    read -p $'Enter postgres user name:\n' PGUSER
fi

if [[ -z "${PGPASSWORD}" ]]; then
    nl=$'\n'
    read -s -p "Enter postgres password for user '${PGUSER}':${nl}" PGPASSWORD
fi

export PGPASSWORD
alias psql="psql -U ${PGUSER} -h ${PGHOST}"

# user didn't supply data dir assume its in the project dir
if [[ -z "${data_dir}" ]]; then
    data_dir="${project_dir}/data"
fi

UNZIPPED_DIR="${data_dir}/unzipped"


create_postgis_db() {
    # if the db exists do nothing
    # http://stackoverflow.com/questions/1454927

    if ! psql -lqtA | grep -q "^${PGDBNAME}|"; then
        createdb -U "${PGUSER}" -h "${PGHOST}" "${PGDBNAME}"
        psql -d "${PGDBNAME}" -c 'CREATE EXTENSION postgis;'
    fi
}

load_rlis_data() {
    local rlis_datasets=( 'streets' 'trails' 'bike_routes' )

    for ds in "${rlis_datasets[@]}"; do
        local ds_path="${data_dir}/${ds}.shp"

        if [[ ! -f "${ds_path}" ]]; then
            local zip_path="${ds_path%.*}.zip"
            local unzip_path="${UNZIPPED_DIR}/${ds}.shp"

            if [[ -f "${zip_path}" ]]; then
                mkdir -p "${UNZIPPED_DIR}"
                unzip -o "${zip_path}" -d "${UNZIPPED_DIR}"
                ds_path="${unzip_path}"
            else
                echo "file: ${ds_path} doesn't not exist, script can't proceed"
                exit 1
            fi
        fi

        # postgres copy command (invoked by -D option) can't handle literal
        # newlines so sed replaces them with newline characters
        shp2pgsql -d -s "${ospn_espg}" -I -D -W 'LATIN1' "${ds_path}" \
            | sed 's/\n/\\n/g' | psql -d "${PGDBNAME}"
    done
}

create_word_table() {
    local abbr_sql="${project_dir}/scripts/abbreviations/create_word_table.sql"
    psql -d "${PGDBNAME}" -v ON_ERROR_STOP=1 -f "${abbr_sql}"
}

load_expanded_data () {
    local src_name='dissolved'
    local src_path="${data_dir}/${src_name}.shp"

    shp2pgsql -d -s "${ospn_espg}" -I -D "${src_path}" 'expanded_names' \
        | psql -d "${PGDBNAME}"
}

main() {
    create_postgis_db
    load_rlis_data
    create_word_table
    load_expanded_data
}

main