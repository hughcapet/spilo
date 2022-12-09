#!/bin/bash
set -ex
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

test_image=(
    'registry.opensource.zalan.do/acid/spilo-cdp-14'
    'spilo'
)
extra_env=(
    ''
    '-e USE_OLD_LOCALES=true'
)

TEST_CONTAINER_NAME='spilo-test'

function stop_container() {
    docker rm -f $1 2>/dev/null
}


for i in $(seq 0 1); do
    stop_container $TEST_CONTAINER_NAME
    docker run --rm -d --privileged \
               --name $TEST_CONTAINER_NAME \
               -v $PWD:/home/postgres/tests \
               -e SPILO_PROVIDER=local ${extra_env[$i]} ${test_image[$i]}
    attempts=0
    while ! docker exec -i spilo-test su postgres -c "pg_isready"; do
        if [[ $attempts -ge 15 ]]; then
            docker logs $TEST_CONTAINER_NAME
            exit 1
        fi
        ((attempts++))
        sleep 1
    done
    /bin/bash -x ./generate_data.sh $TEST_CONTAINER_NAME "/home/postgres/output${i}.txt"
done

diff -u output0.txt output1.txt || (echo "Outputs are different!" && exit 1)

trap stop_container $TEST_CONTAINER_NAME QUIT TERM EXIT
