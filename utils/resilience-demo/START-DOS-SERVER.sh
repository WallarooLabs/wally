#!/bin/sh

. ./COMMON.sh

if [ $USE_DOS_SERVER = y ]; then
    echo Start DOS server
    ssh -n $USER@$DOS_SERVER_EXT "rm -rf /tmp/dos-data ; mkdir /tmp/dos-data"
    ssh -n $USER@$DOS_SERVER_EXT "cd wallaroo ; python ./utils/dos-dumb-object-service/dos-server.py /tmp/dos-data > /tmp/dos-data/errout.txt 2>&1" &
    W_DOS_SERVER_ARG="--resilience-dos-server $DOS_SERVER:9999"
else
    echo Skip starting DOS server
    W_DOS_SERVER_ARG=""
fi
