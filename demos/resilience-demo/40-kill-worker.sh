#!/bin/sh

. ./COMMON.sh

if [ -z "$1" -o -z "$2" ]; then
    echo "usage: $0 worker-number target-machine-number ... where number = 2-4"
    exit 1
else
    SOURCE_WORKER=$1
    eval 'TARGET=$SERVER'$2
    eval 'TARGET_EXT=$SERVER'$2'_EXT'
fi

ssh -n $USER@$TARGET_EXT 'PID=`ps axww | grep worker'$SOURCE_WORKER' | egrep -v "cd wallaroo|grep" | awk '\''{print $1}'\''`; echo Pid is $PID; kill -9 $PID'
