#!/bin/sh

if [ `uname -s` != Linux ]; then
    ## We're using GNU's getopt not BSD's {sigh}
    echo Error: Not a Linux system
    exit 1
fi

EXTERNAL_SENDER=../../../../testing/tools/external_sender/external_sender
COUNT=`expr 15 \* 10` # 15 seconds
VERBOSE=""
ALL_RUNNING=""

# Ref: /usr/share/doc/util-linux/examples/getopt-parse.bash
TEMP=`getopt -o avw: --long all-running,verbose,wait: \
     -n $0 -- "$@"`

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

while true ; do
    case "$1" in
        -a|--all-running) ALL_RUNNING=true; shift 1 ;;
        -v|--verbose) VERBOSE=true; shift 1 ;;
        -w|--wait) COUNT=`expr $2 \* 10`; shift 2 ;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done

## If a worker has crashed, then a `cluster-status-query` that
## is sent to any running worker process will return successfully.
## That's not what we want to know.
##
## NOTE: GH bug #3002 means that we can DoS ourselves by sending
##       this query too soon!  {sigh}
##
## If we use cluster-state-entity-count-query to initializer to check if
## all of the nodes in the cluster are actually running &
## queryable.  The query will hang if one or more of the workers
## has crashed.  Unfortunately, that hang makes scripting
## difficult: the `external_sender` proc can hang forever waiting
## for a reply from Wallaroo that will never arrive.
##
## Our workaround is to use our external TCP port numbering scheme to
## query each worker directly.  We assume that the initializer's
## cluster membership info is the Source of Truth(tm).

initializer_external="${WALLAROO_INIT_HOST}:${WALLAROO_MY_EXTERNAL_BASE}"


for i in `seq 1 $COUNT`; do
    $EXTERNAL_SENDER \
        -e $initializer_external -t cluster-status-query 2>&1 | \
      grep -s 'Processing messages: true' > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        break;
    fi
    if [ ! -z "$VERBOSE" ]; then
        echo -n .
    fi
    sleep 0.1
done

if [ $i -eq $COUNT ]; then
    $EXTERNAL_SENDER \
        -e $initializer_external -t cluster-status-query 2>&1 | \
    echo Failed
    exit 1
fi

if [ ! -z "$ALL_RUNNING" ]; then
    workers=`$EXTERNAL_SENDER \
        -e $initializer_external -t cluster-status-query 2>&1 | \
      grep -s 'Processing messages: ' | \
      sed -e 's/.*Workers: .//' -e 's/,|.*//' | \
      tr ',' ' '`
    for worker in $workers; do
        if [ ! -z "$VERBOSE" ]; then
            echo -n "Worker $worker: "
        fi
        base_port=7103
        case $worker in
            initializer)
                port=$base_port
                ;;
            worker*)
                n=`echo $worker | sed 's/worker//'`
                my_shift=`expr $n \* 10`
                port=`expr $base_port + $my_shift`
                ;;
            *)
                echo Error: unknown worker $worker
                exit 1
                ;;
        esac
        if [ ! -z "$VERBOSE" ]; then
            echo -n port = $port
        fi
        for i in `seq 1 $COUNT`; do
            $EXTERNAL_SENDER \
                -e 127.0.0.1:$port -t cluster-status-query 2>&1 | \
                grep -s 'Processing messages: true' > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                if [ ! -z "$VERBOSE" ]; then
                    echo ""
                fi
                break;
            fi
            if [ ! -z "$VERBOSE" ]; then
                echo -n .
            fi
            sleep 0.1
        done
        if [ $i -eq $COUNT ]; then
            if [ ! -z "$VERBOSE" ]; then
                break
            fi
        fi
    done
fi

if [ $i -eq $COUNT ]; then
    if [ ! -z "$VERBOSE" ]; then
        echo Failed
    fi
    exit 1
else
    if [ ! -z "$VERBOSE" ]; then
        echo Success
    fi
    exit 0
fi
