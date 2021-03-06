#!/bin/bash

function sudo {
    if [[ $# -eq 0 ]]; then
        echo "Usage: sudo program arg1 arg2 ..."
        return 1
    fi
    prog="$1"
    shift
    cygstart --hide --action=runas $(which "$prog") "$@"
}

if [[ $(basename ${BASH_SOURCE}) == $(basename $0) ]]; then
    sudo "$@"
fi
