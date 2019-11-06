#!/bin/sh

if [ `uname -s` != Linux -a `uname -s` != Darwin ]; then
    echo Error: Not a Linux or MacOS system
    exit 1
fi

if [ -z "$1" ]; then
    echo Usage: $0 worker-number
    exit 1
fi

CLUSTER_SHRINKER=../../../../utils/cluster_shrinker/cluster_shrinker

case $1 in
    0)
        echo Error: cannot shrink the initializer worker
        exit 1
        ;;
    [1-9]*)
        name=worker$1
        pattern="name worker$1"
        ;;
    *)
        echo Error: bad worker number $1
        exit 1
        ;;
esac

pid=`ps axww | grep -v grep | grep "$pattern" | awk '{print $1}'`
if [ -z "$pid" ]; then
    echo Error: worker $name is not running
    exit 1
fi

eligible=`$CLUSTER_SHRINKER -e 127.0.0.1:$WALLAROO_MY_EXTERNAL_BASE -q | \
    sed -e 's/.*Nodes: .//' -e 's/,|.*//' | \
      tr ',' ' '`
ok=0
for e in $eligible; do
    if [ $e = $name ]; then
        ok=1
        break
    fi
done

if [ $ok -eq 0 ]; then
    echo Error: worker $name is not eligible to be shrunk
    echo Error: eligible list: $eligible
    exit 1
fi

$CLUSTER_SHRINKER -e 127.0.0.1:$WALLAROO_MY_EXTERNAL_BASE -w $name

exit 0
