#!/bin/sh

DESIRED=$1
if [ -z "$DESIRED" ]; then
    echo "Usage: $0 num-desired [crash options...]"
    exit 1
fi
shift

export PATH=.:$PATH
export PYTHONPATH=$HOME/wallaroo/machida/lib:$HOME/wallaroo/examples/python/celsius_connectors:$PYTHONPATH
export WALLAROO_BIN=$HOME/wallaroo/examples/pony/passthrough/passthrough
export WALLAROO_THRESHOLDS='*.8'
. ./sample-env-vars.sh

reset () {
    reset.sh
    ps axww | grep master-crasher.sh | grep -v $$ | awk '{print $1}' | xargs kill -9
}

start_sink () {
    ~/wallaroo/testing/correctness/tests/aloc_sink/aloc_sink /tmp/sink-out/output /tmp/sink-out/abort 7200 >> /tmp/sink-out/stdout-stderr 2>&1 &
}

stop_sink () {
    ps axww | grep python | grep aloc_sink | awk '{print $1}' | xargs kill
}

start_initializer () {
    echo start-initializer.sh $*
    start-initializer.sh $*
}

poll_ready () {
    poll-ready.sh -a -v -w 5
}

start_all_workers () {
    start_initializer -n $DESIRED
    sleep 1
    DESIRED_1=`expr $DESIRED - 1`
    for i in `seq 1 $DESIRED_1`; do
        start_worker -n $DESIRED $i
        sleep 1
    done
    poll_ready || exit 1
}

start_sender () {
    outfile=/tmp/sender.out
    rm -f $outfile
    while [ 1 ]; do
        $HOME/wallaroo/testing/correctness/scripts/effectively-once/at_least_once_line_file_feed /tmp/input-file.txt 41000 > $outfile 2>&1
        sleep 0.1
    done
}

random_float () {
    python -c 'import random; import math; print (random.random() * '$1')'
}

random_int () {
    python -c 'import random; import math; print math.trunc(random.random() * '$1')'
}

random_sleep () {
    base=`random_float $1`
    if [ -z "$2" ]; then
        extra=0.0
    else
        extra=$2
    fi
    sleep `python -c "print $base + $extra"`
}

crash_sink () {
    ps axww | grep python3 | grep /aloc_sink | awk '{print $1}' | xargs kill -9
}

run_crash_sink_loop () {
    sleep 1
    while [ 1 ]; do
        crash_sink
        random_sleep 2
        start_sink
        random_sleep 5 5
    done
}

run_sanity_loop () {
    while [ 1 ]; do
        sleep 1
        echo -n ,
        egrep 'ERROR|FATAL|CRIT' /tmp/sink-out/stdout-stderr
        if [ $? -eq 0 ]; then
            echo SANITY
            break
        fi
        ./1-to-1-passthrough-verify.sh /tmp/input-file.txt
        if [ $? -ne 0 ]; then
            echo BREAK2
            break
        fi
    done
    echo "SANITY LOOP FAILURE: stop the world"
    killall -STOP passthrough
    killall -STOP master-crasher.sh
}

reset
start_sink ; sleep 1
start_all_workers
start_sender &

run_sanity=true
for arg in $*; do
    case $arg in
        crash-sink)
            echo RUN: run_crash_sink_loop
            run_crash_sink_loop &
            ;;
        no-sanity)
            echo NO RUN: run_sanity_loop
            run_sanity=false
            ;;
    esac
done

if [ $run_sanity ]; then
    run_sanity_loop &
fi

echo Done, yay ... waiting
wait
exit 0