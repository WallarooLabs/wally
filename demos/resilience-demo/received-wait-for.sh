#!/bin/sh

RECEIVED=$1
NUM_KEYS=$2
SEQ_NUM=$3
TIMEOUT=$4

if [ ! -f $RECEIVED -o -z $NUM_KEYS -o -z $SEQ_NUM -o -z $TIMEOUT ]; then
    echo Usage: $0 /path/to/received.txt number-of-keys final-sequence-number timeout-seconds
    exit 1
fi

NOW=`date +%s`
STOP=`expr $NOW + $TIMEOUT`

while [ 1 ]; do
    C=`strings $RECEIVED | egrep ",${SEQ_NUM}\\]" | sort -u | wc -l`
    if [ $C -eq $NUM_KEYS ]; then
        exit 0
    fi
    if [ `date +%s` -gt $STOP ]; then
        echo TIMEOUT
        exit 1
    fi
    sleep 0.1
done

