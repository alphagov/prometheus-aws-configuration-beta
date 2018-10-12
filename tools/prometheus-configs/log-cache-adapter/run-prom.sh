#!/bin/bash

set -eu

# cleanup and exit if either the cf oauth-token or the prometheus jobs terminate
# or if the user presses C-c
set -m # needed to handle CHLD signals
trap "cleanup_and_exit" CHLD INT

TOKEN_FILE=./token

cleanup_and_exit() {
    # shellcheck disable=SC2046
    kill $(jobs -p)
    exit
}

refresh_token() {
    while true ; do
        TOKEN=$(cf oauth-token 2> /dev/null)
        if [ $? != 0 ] ; then
            # shellcheck disable=SC2016
            echo 'The call to `cf oauth-token` failed.  Are you logged in?'
            exit 1
        fi
        echo "$TOKEN" | sed 's/bearer //' > $TOKEN_FILE
        sleep 120
    done
}

refresh_token &

prometheus --config.file=./prometheus.yml &

wait
