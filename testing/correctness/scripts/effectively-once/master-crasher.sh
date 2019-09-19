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
    start-initializer.sh $*
}

start_worker () {
    start-worker.sh $*
}

poll_ready () {
    poll-ready.sh $*
}

pause_the_world () {
    killall -STOP passthrough
    killall -STOP master-crasher.sh
}

start_all_workers () {
    start_initializer -n $DESIRED
    sleep 1
    DESIRED_1=`expr $DESIRED - 1`
    for i in `seq 1 $DESIRED_1`; do
        start_worker -n $DESIRED $i
        sleep 1
    done
    poll_ready -a -v -w 5 || exit 1
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

crash_worker () {
    worker="$1"
    if [ -z "$worker" ]; then
        echo ERROR: $0: worker number not given
        exit 1
    fi
    crash-worker.sh $worker
}

run_crash_sink_loop () {
    sleep 1
    #for i in `seq 1 1`; do
    while [ 1 ]; do
        echo -n cS
        crash_sink
        random_sleep 2
        echo -n rS
        start_sink
        random_sleep 10 5
    done
}

run_crash_worker_loop () {
    worker="$1"
    if [ -z "$worker" ]; then
        echo ERROR: $0: worker number not given
        exit 1
    fi
    while [ 1 ]; do
        sleep `random_float 4.5 0`
        echo -n "c$worker"
        crash_worker $worker
        sleep `random_float 2.5 0`
        if [ $worker -eq 0 ]; then
            start_initializer
        else
            start_worker $worker
        fi
        echo -n "r$worker"
        sleep 0.25
        poll_ready -w 2
        if [ $? -ne 0 ]; then
            echo "CRASH LOOP $worker: pause the world"
            pause_the_world
        fi
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
    echo "SANITY LOOP FAILURE: pause the world"
    pause_the_world
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
        crash[0-9]*)
            worker=`echo $arg | sed 's/crash//'`
            cmd="run_crash_worker_loop $worker"
            echo RUN: $cmd
            $cmd &
            ;;
    esac
done

if [ $run_sanity ]; then
    run_sanity_loop &
fi

echo Done, yay ... waiting
wait
exit 0
