#!/bin/bash

readonly container=$1
readonly tests_dir="/home/postgres/tests"
readonly output_file=$2

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

if ! docker info &> /dev/null; then
    if podman info &> /dev/null; then
        alias docker=podman
        shopt -s expand_aliases
    else
        echo "docker/podman: command not found"
        exit 1
    fi
fi


function docker_exec() {
    declare -r cmd=${*: -1:1}
    docker exec "${@:1:$(($#-1))}" su postgres -c "$cmd"
}


function generate_data() {
    docker_exec "$container" $'cd $PGDATA;
        rm -rf locales_test; mkdir locales_test; cd locales_test;
        /bin/bash "/home/postgres/tests/helper_script.sh";
        for filename in ./_base-characters*; do
            truncate -s -1 $filename \
            && psql -c "insert into chars select regexp_split_to_table(pg_read_file(\'locales_test/${filename}\')::text, E\'\\n\');"
        done
    '
}

# Create an auxiliary table
docker_exec "$container" "psql -d postgres -c 'drop table if exists chars; create table chars(chr text);'"

# Insert data into the auxiliary table
generate_data

# Write sorted data to an output file
docker_exec "$container" "psql -c '\copy (select * from chars order by 1) to ${output_file}'"
docker_exec "$container" "truncate -s -1 ${output_file}"
docker exec "$container" cp ${output_file} ${tests_dir}
