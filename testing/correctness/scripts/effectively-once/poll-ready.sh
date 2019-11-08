#!/bin/sh

if [ `uname -s` != Linux -a `uname -s` != Darwin ]; then
    echo Error: Not a Linux or MacOS system
    exit 1
fi

EXTERNAL_SENDER=../../../../testing/tools/external_sender/external_sender
COUNT=`expr 15 \* 10` # 15 seconds
VERBOSE=""
ALL_RUNNING=""
ALL_RUNNING_LIMITED_STATUS=""
SKIP_INITIAL_CHECK=""

TEMP=`getopt aASvw: $*`

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

eval set -- $TEMP

while true ; do
    case "$1" in
        -a) ALL_RUNNING=true; shift 1 ;;
        -A) ALL_RUNNING_LIMITED_STATUS=true; shift 1 ;;
        -S) SKIP_INITIAL_CHECK=true; shift 1 ;;
        -v) VERBOSE=true; shift 1 ;;
        -w) COUNT=`expr $2 \* 10`; shift 2 ;;
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

if [ -z "$SKIP_INITIAL_CHECK" ]; then
    for i in `seq 1 $COUNT`; do
        $EXTERNAL_SENDER \
            -e $initializer_external -t cluster-status-query 2>&1 | \
          grep -s 'Processing messages: true' > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            break;
        fi
        if [ ! -z "$VERBOSE" ]; then
            /bin/echo -n .
        fi
        sleep 0.1
    done

    if [ $i -eq $COUNT ]; then
        $EXTERNAL_SENDER \
            -e $initializer_external -t cluster-status-query 2>&1
        echo Failed
        exit 1
    fi
fi

i=0
if [ ! -z "$ALL_RUNNING" ]; then
    workers=`$EXTERNAL_SENDER \
        -e $initializer_external -t cluster-status-query 2>&1 | \
      grep -s 'Processing messages: ' | \
      sed -e 's/.*Workers: .//' -e 's/,|.*//' | \
      tr ',' ' '`
    for worker in $workers; do
        if [ ! -z "$VERBOSE" ]; then
            /bin/echo -n "Worker $worker: "
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
            /bin/echo -n port = $port
        fi
        for i in `seq 1 $COUNT`; do
            output=`$EXTERNAL_SENDER \
                -e 127.0.0.1:$port -t cluster-status-query 2>&1`
            if [ -z "$ALL_RUNNING_LIMITED_STATUS" ]; then
                echo "$output" | \
                    grep -s 'Processing messages: true' > /dev/null 2>&1
            else
                echo "$output" | \
                    grep -s 'Processing messages: ' > /dev/null 2>&1
            fi
            if [ $? -eq 0 ]; then
                if [ ! -z "$VERBOSE" ]; then
                    echo ""
                fi
                break;
            fi
            if [ ! -z "$VERBOSE" ]; then
                /bin/echo -n .
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
        echo Failed for count $COUNT on worker $worker: $output
    fi
    exit 1
else
    if [ ! -z "$VERBOSE" ]; then
        echo Success
    fi
    exit 0
fi
