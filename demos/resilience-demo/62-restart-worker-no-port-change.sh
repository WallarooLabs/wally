#!/bin/sh

. ./COMMON.sh

if [ -z "$1" -o -z "$2" ]; then
    echo "usage: $0 source-worker-number target-worker-number ... where worker-number = 2-4"
    exit 1
else
    SOURCE_WORKER=$1
    eval 'TARGET=$SERVER'$2
    eval 'TARGET_EXT=$SERVER'$2'_EXT'
fi

SKIP_DOS_SERVER_START=y
. ./START-DOS-SERVER.sh

ssh -n $USER@$TARGET_EXT "cd wallaroo ; ulimit -c unlimited; mkdir -p /tmp/run-dir/OLD; mv /tmp/run-dir/market*out /tmp/run-dir/OLD; $WALLAROO_BIN -i ${SERVER1}:7000,${SERVER1}:7001 -o ${SERVER1}:5555 -m ${SERVER1}:5001 -c ${SERVER1}:12500 -n worker${SOURCE_WORKER} --my-control ${TARGET}:13131 --my-data ${TARGET}:13132 $W_DOS_SERVER_ARG --ponynoblock > /tmp/run-dir/${WALLAROO_NAME}${SOURCE_WORKER}.`date +%s`.out 2>&1" > /dev/null 2>&1 &
if [ -z "$RESTART_SLEEP" ]; then
    sleep 2
else
    echo sleeping for RESTART_SLEEP=$RESTART_SLEEP
    sleep $RESTART_SLEEP
fi

for i in $SERVER1_EXT $TARGET_EXT; do
    /bin/echo -n "Check Wallaroo worker on ${i}: "
    LIM=30
    C=0
    while [ $C -lt $LIM ]; do
        /bin/echo -n .
        ssh -n $USER@$i "grep III /tmp/run-dir/${WALLAROO_NAME}*out"
        if [ $? -eq 0 ]; then
            break
        fi
        sleep 0.2
        C=`expr $C + 1`
    done
    if [ $C -ge $LIM ]; then
        echo TIMEOUT
        exit 1
    fi
done
