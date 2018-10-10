#!/bin/sh

. ./COMMON.sh

if [ -z "$1" ]; then
    echo "usage: $0 worker-number ... where worker-number = 2-4"
    exit 1
else
    eval 'TARGET_EXT=$SERVER'$1'_EXT'
fi

ssh -n $USER@$TARGET_EXT 'PID=`ps axww | grep worker'$1' | egrep -v "cd wallaroo|grep" | awk '\''{print $1}'\''`; echo Pid is $PID; kill -9 $PID'
