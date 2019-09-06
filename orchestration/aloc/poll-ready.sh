#!/bin/sh

if [ `uname -s` != Linux ]; then
    ## We're using GNU's getopt not BSD's {sigh}
    echo Error: Not a Linux system
    exit 1
fi

COUNT=`expr 15 \* 10` # 15 seconds
VERBOSE=""

# Ref: /usr/share/doc/util-linux/examples/getopt-parse.bash
TEMP=`getopt -o vw: --long v-long,w-long: \
     -n $0 -- "$@"`

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

while true ; do
    case "$1" in
        -v|--v-long) VERBOSE=true; shift 1 ;;
        -w|--w-long) COUNT=`expr $2 \* 10`; shift 2 ;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done

for i in `seq 1 $COUNT`; do
    ../../testing/tools/external_sender/external_sender \
        -e $WALLAROO_ARG_EXTERNAL -t cluster-status-query 2>&1 | \
      grep -s 'Processing messages: true' > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        if [ ! -z "$VERBOSE" ]; then
            echo Success
        fi
        exit 0
    fi
    if [ ! -z "$VERBOSE" ]; then
        echo -n .
    fi
    sleep 0.1
done

if [ ! -z "$VERBOSE" ]; then
    echo Failed
fi
exit 1
