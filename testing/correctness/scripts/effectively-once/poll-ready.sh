#!/bin/sh

if [ `uname -s` != Linux -a `uname -s` != Darwin ]; then
    echo Error: Not a Linux or MacOS system
    exit 1
fi

EXTERNAL_SENDER=../../../../testing/tools/external_sender/external_sender
COUNT=`expr 15 \* 10` # 15 seconds
VERBOSE=""

TEMP=`getopt aASvw: $*`

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

eval set -- $TEMP

while true ; do
    case "$1" in
        -v) VERBOSE=true; shift 1 ;;
        -w) COUNT=`expr $2 \* 10`; shift 2 ;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done

worker="$1"
if [ -z "$worker" ]; then
    echo Error: worker number not specified
    exit 1
fi
base_port=${WALLAROO_MY_EXTERNAL_BASE}
my_shift=`expr $worker \* 10`
port=`expr $base_port + $my_shift`
if [ ! -z "$VERBOSE" ]; then
    echo "TCP port number = $port"
fi

## If a worker has crashed, then a `cluster-status-query` that
## is sent to any running worker process will return successfully.
## That's not what we want to know.
##
## NOTE: GH bug #3002 means that we can DoS ourselves by sending
##       this query too soon!  {sigh}
##
## If we used cluster-state-entity-count-query to initializer to check if
## all of the nodes in the cluster are actually running &
## queryable, the query may hang if one or more of the workers
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

if [ ! -z "$VERBOSE" ]; then
    echo Success
fi
exit 0
