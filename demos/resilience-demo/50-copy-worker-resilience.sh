#!/bin/sh

. ./COMMON.sh

if [ -z "$1" -o -z "$2" ]; then
    echo "usage: $0 worker-number source-machine-number target-machine-number ... where number = 2-4"
    exit 1
else
    SOURCE_WORKER=$1
    eval 'SOURCE=$SERVER'$2
    eval 'SOURCE_EXT=$SERVER'$2'_EXT'
    eval 'TARGET=$SERVER'$3
    eval 'TARGET_EXT=$SERVER'$3'_EXT'
fi

if [ $RESTORE_VIA_JOURNAL_DUMP = y ]; then
    echo Rsync journal file from DOS server $DOS_SERVER to $TARGET
    ssh -n $USER@$TARGET_EXT "rm -vf /tmp/${WALLAROO_NAME}*"
    ssh -A -n $USER@$TARGET_EXT "rsync -raH -v -e 'ssh -o \"StrictHostKeyChecking no\"' ${DOS_SERVER}:/tmp/dos-data/worker${SOURCE_WORKER}/\* /tmp"

    echo Extract journalled I/O ops from the journal file
    # ssh -n $USER@$TARGET_EXT "echo BEFORE ; ls -l /tmp/mar*"
    ssh -n $USER@$TARGET_EXT "cd wallaroo ; python ./testing/tools/dos-dumb-object-service/journal-dump.py /tmp/${WALLAROO_NAME}-worker${SOURCE_WORKER}.journal"
    echo Copy ${WALLAROO_NAME}-worker${SOURCE_WORKER}.evlog.journal '->' ${WALLAROO_NAME}-worker${SOURCE_WORKER}.evlog
    ssh -n $USER@$TARGET_EXT "cp /tmp/${WALLAROO_NAME}-worker${SOURCE_WORKER}.evlog.journal /tmp/${WALLAROO_NAME}-worker${SOURCE_WORKER}.evlog"
    # ssh -n $USER@$TARGET_EXT "echo AFTER ; ls -l /tmp/mar*"
    # sleep 3
else
    echo
    echo "NOTE: rsync all resilience files directly from 'failed' worker (cheating)"
    echo

    ssh -A -n $USER@$TARGET_EXT "rsync -raH -v -e 'ssh -o \"StrictHostKeyChecking no\"' ${SOURCE}:/tmp/${WALLAROO_NAME}\* /tmp"
fi

echo
echo "NOTE: Kludge to fix up tcp-control and tcp-data files, TODO"
echo

. ./KLUDGE-TCP-FILES.sh
