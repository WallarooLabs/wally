#!/bin/sh

if [ `uname -s` != Linux -a `uname -s` != Darwin ]; then
    echo Error: Not a Linux or MacOS system
    exit 1
fi

if [ -z "$WALLAROO_BIN" -o ! -x "$WALLAROO_BIN" ]; then
    echo "Error: WALLAROO_BIN env var not set or executable '$WALLAROO_BIN' does not exist"
    exit 1
fi

NUM_WORKERS=1
VERBOSE=""

TEMP=`getopt n:v $*`

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

eval set -- $TEMP

while true ; do
    case "$1" in
        -n) NUM_WORKERS=$2; shift 2 ;;
        -v) VERBOSE=true; shift 1 ;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done
WORKER=$1

if [ ! -z "$VERBOSE" ]; then
    echo NUM_WORKERS=$NUM_WORKERS
    echo VERBOSE=$VERBOSE
fi

my_in=`echo $WALLAROO_ARG_IN | \
    sed -e "s/__IN_HOST__/$WALLAROO_INIT_HOST/" \
        -e "s/__IN_PORT__/$WALLAROO_IN_BASE/"`
my_external="${WALLAROO_INIT_HOST}:${WALLAROO_MY_EXTERNAL_BASE}"

cmd="$WALLAROO_BIN --in $my_in \
     $WALLAROO_BASE_ARGS --data $WALLAROO_ARG_DATA \
     --cluster-initializer \
     --external $my_external \
     --worker-count $NUM_WORKERS \
     $WALLAROO_ARG_PONY"
if [ ! -z "$VERBOSE" ]; then
    echo "cmd: $cmd > /tmp/wallaroo.0 2>&1 &"
fi

eval "$cmd" > /tmp/wallaroo.0 2>&1 &

exit 0
