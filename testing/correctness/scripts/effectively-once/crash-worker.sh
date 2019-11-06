#!/bin/sh

if [ `uname -s` != Linux -a `uname -s` != Darwin ]; then
    echo Error: Not a Linux or MacOS system
    exit 1
fi

if [ -z "$1" ]; then
    echo Usage: $0 worker-number
    exit 1
fi

case $1 in
    0)
        name=initializer
        pattern="cluster-initializer"
        ;;
    [1-9]*)
        name=worker$1
        pattern="name worker$1"
        ;;
    *)
        echo Error: bad worker number: $1
        exit 1
        ;;
esac

pid=`ps axww | grep -v grep | grep "$pattern" | awk '{print $1}'`
if [ -z "$pid" ]; then
    echo Error: worker $name is not running
    exit 1
fi

kill -9 $pid
exit 0
