#!/usr/bin/env bash

dbname=

data_dir="$( cd  $(dirname ${0}); dirname $(pwd -P) )/data"
datasets=( 'streets' 'trails' )

createdb

shp2pgsql | psql -d