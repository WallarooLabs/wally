#!/bin/sh

if [ `uname -s` != Linux ]; then
    ## We're using GNU's getopt not BSD's {sigh}
    echo Error: Not a Linux system
    exit 1
fi

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

if [ ! -z "$ALL_RUNNING" ]; then
    ## Use cluster-state-entity-count-query to initializer to check if
    ## all of the nodes in the cluster are actually running &
    ## queryable.  The query will hang if one or more of the workers
    ## has crashed.  Unfortunately, that hang makes scripting
    ## difficult: the `external_sender` proc can hang forever waiting
    ## for a reply from Wallaroo that will never arrive.
    ##
    ## If a worker *has* crashed, then a `cluster-status-query` that
    ## is sent to any running worker process will return successfully.
    ## That's not what we want to know.
    ##
    ## The only way that I can think of around this problem is to send
    ## a `cluster-status-query` and then parse the output, e.g.,
    ## Processing messages: true, Worker count: 2, Workers: |initializer,worker2,|,
    ## then map the worker name -> Wallaroo external TCP port, then
    ## send a `cluster-status-query` to each of the workers.  But that
    ## embeds a lot more Wallaroo internal knowledge (and also the TCP
    ## port number convention used by these shell scripts).
    ##
    ## NOTE: GH bug #3002 means that we can DoS ourselves by sending
    ##       this query too soon!  {sigh}

    if [ ! -z "$VERBOSE" ]; then
        echo -n "Entity count: "
    fi
    OUTFILE=`tempfile -d /tmp`
    trap "rm -f $OUTFILE" 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15
    for i in `seq 1 $COUNT`; do
        ../../testing/tools/external_sender/external_sender \
            -e $WALLAROO_ARG_EXTERNAL \
            -t cluster-state-entity-count-query > $OUTFILE 2>&1 &
        PID=$!
        sleep 0.1
        grep -s initializer $OUTFILE > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            if [ ! -z "$VERBOSE" ]; then
                echo Success
            fi
            break
        fi
        if [ ! -z "$VERBOSE" ]; then
            echo -n .
        fi
    done
    if [ $i -eq $COUNT ]; then
        if [ ! -z "$VERBOSE" ]; then
            echo Failed
        fi
        exit 1
    fi
fi

if [ ! -z "$VERBOSE" ]; then
    echo -n "Processing messages: "
fi
for i in `seq 1 $COUNT`; do
    ../../testing/tools/external_sender/external_sender \
        -e $WALLAROO_ARG_EXTERNAL -t cluster-status-query 2>&1 | \
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
