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
    ps axww | grep master-crasher.sh | grep -v $$ | awk '{print $1}' | xargs kill -9  > /dev/null 2>&1
    stop_sink > /dev/null 2>&1
    stop_sender > /dev/null 2>&1
}

start_sink () {
    $HOME/wallaroo/utils/data_receiver/data_receiver \
        --listen 0.0.0.0:$WALLAROO_OUT_PORT --ponythreads=1 \
        >> /tmp/sink-out/output 2>&1 &
}

stop_sink () {
    ps axww | grep -v grep | grep data_receiver | awk '{print $1}' | xargs kill -9
}

start_initializer () {
    start-initializer.sh $*
}

start_worker () {
    start-worker.sh $*
}

join_worker () {
    join-worker.sh $*
}

shrink_worker () {
    shrink-worker.sh $*
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
        $HOME/wallaroo/testing/tools/fixed_length_message_blaster/fixed_length_message_blaster \
            --host localhost:$WALLAROO_IN_BASE --file /tmp/input-file.txt \
            --msg-size 53 --batch-size 6 \
            --msec-interval 5 --report-interval 1000000 --ponythreads=1 \
            >> $outfile 2>&1
        sleep 0.1
    done
}

stop_sender () {
    ps axww | grep -v grep | grep fixed_length_message_blaster | awk '{print $1}' | xargs kill
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
    stop_sink
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
    sleep 2 # Don't start crashing until checkpoint #1 is complete.
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
    sleep 2 # Don't start crashing until checkpoint #1 is complete.
    while [ 1 ]; do
        sleep `random_float 4.5 0`
        echo -n "c$worker"
        crash_out=`crash_worker $worker`
        mv /tmp/wallaroo.$worker /tmp/wallaroo.$worker.`date +%s` && gzip /tmp/wallaroo.$worker.`date +%s` &
        if [ -z "$crash_out" ]; then
            sleep `random_float 2.5 0`
            if [ $worker -eq 0 ]; then
                start_initializer
            else
                start_worker $worker
            fi
        else
            echo "Crash of $worker failed: $crash_out"
            pause_the_world
            break
        fi
        echo -n "r$worker"
        sleep 0.25
        poll_out=`poll_ready -w 4 2>&1`
        status=$?
        if [ $status -ne 0 -o ! -z "$poll_out" ]; then
            echo "CRASH LOOP $worker: pause the world: exit $status reason $poll_out"
            pause_the_world
            break
        fi
    done
}

run_sanity_loop () {
    ##echo run_sanity_loop: not valid for TCP source and sink, skipping
    outfile=/tmp/sanity-loop.out
    while [ 1 ]; do
        sleep 1
        echo -n ,
        ## stdout-stderr does not exist
        #egrep 'ERROR|FATAL|CRIT' /tmp/sink-out/stdout-stderr
        #if [ $? -eq 0 ]; then
        #    echo SANITY
        #    break
        #fi
        
        ## verification script's assumptions are not met by TCPSink
        #./1-to-1-passthrough-verify.sh /tmp/input-file.txt > $outfile 2>&1
        #if [ $? -ne 0 ]; then
        #    head $outfile
        #    rm $outfile
        #    echo BREAK2
        #    break
        #fi
        rm -f $outfile
    done
    echo "SANITY LOOP FAILURE: pause the world"
    pause_the_world
}

get_worker_names () {
    external_sender=../../../../testing/tools/external_sender/external_sender
    initializer_external="${WALLAROO_INIT_HOST}:${WALLAROO_MY_EXTERNAL_BASE}"
    $external_sender \
        -e $initializer_external -t cluster-status-query 2>&1 | \
      grep -s 'Processing messages: ' | \
      sed -e 's/.*Workers: .//' -e 's/,|.*//' | \
      tr ',' ' '
}

run_grow_shrink_loop () {
    all_workers="initializer worker1 worker2 worker3 worker4 worker5 worker6 worker7 worker8 worker9"
    do_grow=0
    do_shrink=0

    case "$1" in
        *grow*)
            do_grow=1
            ;;
    esac
    case "$1" in
        *shrink*)
            do_shrink=1
            ;;
    esac
    echo DBG: do_grow = $do_grow, do_shrink = $do_shrink

    sleep 2 # Don't start crashing until checkpoint #1 is complete.
    while [ 1 ]; do
        if [ $do_grow -eq 1 -a  `random_int 10` -lt 5 ]; then
            running_now=`get_worker_names`
            for w in $all_workers; do
                found=""
                for running in $running_now; do
                    if [ $w = $running ]; then
                        found=$w
                        break;
                    fi
                done
                if [ -z "$found" ]; then
                    echo -n "Join $w."
                    worker_num=`echo $w | sed 's/worker//'`
                    join_worker -n 1 $worker_num
                    sleep 1
                    poll_out=`poll_ready -w 4 2>&1`
                    if [ $? -ne 0 -o ! -z "$poll_out" ]; then
                        echo "GROW LOOP join $w: pause the world: $poll_out"
                        pause_the_world
                        break
                    fi
                    break # Don't join more than 1 worker at a time
                fi
            done
        fi
        if [ $do_shrink -eq 1 -a `random_int 10` -lt 5 ]; then
            running_now=`get_worker_names`
            for running in $running_now; do
                if [ $running = initializer ]; then
                    continue
                fi
                if [ `random_int 10` -lt 5 ]; then
                    echo -n "Shrink $running"
                    worker_num=`echo $running | sed 's/worker//'`
                    shrink_worker $worker_num
                    sleep 1
                    poll_out=`poll_ready -w 4 2>&1`
                    if [ $? -ne 0 -o ! -z "$poll_out" ]; then
                        echo "GROW LOOP shrink $w: pause the world: $poll_out"
                        pause_the_world
                        break
                    fi
                    break # Don't shrink more than 1 worker at a time
                fi
            done
        fi
        sleep 1
        if [ ! -z "$CUSTOM_SHRINK_MANY" ]; then
            ## echo -n Shrink-$CUSTOM_SHRINK_MANY
            CLUSTER_SHRINKER=../../../../utils/cluster_shrinker/cluster_shrinker
            out=`$CLUSTER_SHRINKER -e 127.0.0.1:$WALLAROO_MY_EXTERNAL_BASE -w $CUSTOM_SHRINK_MANY 2>&1 | grep -v 'Invalid shrink targets'`
            if [ ! -z "$out" ]; then
                # Shrink op started
                echo $out
                sleep 1
                poll_out=`poll_ready -w 4 2>&1`
                if [ $? -ne 0 -o ! -z "$poll_out" ]; then
                    echo "custom hack $w: $poll_out"
                    pause_the_world
                    break
                fi
            fi
        fi
    done
}

run_custom1 () {
    ## Assume that we are run with `./master-crasher.sh 3 no-sanity run_custom1`

    sleep 2

    echo -n "Shrink worker2"
    shrink_worker 2
    sleep 2

    echo -n "Join worker2 again"
    join_worker 2
    sleep 1

    # We expect that this loop, now that it has been started, will
    # fail immediately, probably because of a CRITICAL error in the
    # sink's log output.
    run_sanity_loop &

    sleep 5
}

run_custom2 () {
    ## Assume that we are run with `./master-crasher.sh 3 no-sanity run_custom2`

    sleep 2
    for i in `seq 4 8`; do
        echo -n "Join worker$i"
        join_worker $i
        sleep 1
    done

    echo -n "Shrink worker7"
    shrink_worker 7
    sleep 2

    echo -n "Join worker7 again"
    join_worker 7
    sleep 1

    # We expect that this loop, now that it has been started, will
    # fail immediately, probably because of a CRITICAL error in the
    # sink's log output.
    run_sanity_loop &

    sleep 5
}

run_custom3 () {
    export CUSTOM_SHRINK_MANY="worker1,worker2,worker3,worker4,worker5,worker6,worker7,worker8,worker9"
    cmd="run_grow_shrink_loop grow"
    echo RUN: $cmd
    $cmd &
}

run_custom4 () {
    ## Assume that we are run with `./master-crasher.sh 9 run_custom4`
    ## Then connector sink output for key 'T' should
    ## be sent first to worker7.
    ## Shrink 7, then output goes to 1.
    ## Shrink 1, then output goes to 3.
    ## Shrink 3, then output goes to 6.
    ## Shrink 2, then output goes to initializer.
    ## Can't shrink initializer, so game over
    sleep 3

    for i in 7 1 3 6 2; do
        echo -n "Shrink worker$i"
        shrink_worker $i
        sleep 1
        poll_out=`poll_ready -w 4 2>&1`
        if [ $? -ne 0 -o ! -z "$poll_out" ]; then
            echo "custom4 shrinking worker$i: $poll_out"
            pause_the_world
            exit 1
        fi
        sleep 1.3 # Give output a chance to accumulate a bit at sink.
    done
    sleep 3
    echo "Pause the world, whee. Last output should be via initializer."
    pause_the_world
}

run_custom5 () {
    ## Assume that we are run with `./master-crasher.sh 3 run_custom5`
    ## Ouput for key 'T' should go to worker2 in an initializer/1/2 cluster.
    sleep 2

    for i in `seq 1 2`; do
        for cmd in "shrink_worker 2" "shrink_worker 1" \
                   "join_worker 1" "join_worker 2"; do
            echo -n $cmd
            $cmd
            sleep 1
            poll_out=`poll_ready -w 4 2>&1`
            if [ $? -ne 0 -o ! -z "$poll_out" ]; then
                echo "custom5 cmd $cmd: $poll_out"
                pause_the_world
                exit 1
            fi
            sleep 1.5
        done
    done
    echo -n "join_worker 3"
    join_worker 3
    sleep 3
}

run_custom3006 () {
    ## Assume that we are run with `./master-crasher.sh 2 run_custom306`
    ## See https://github.com/WallarooLabs/wallaroo/issues/3006
    sleep 2

    while [ 1 ]; do
        echo -n c0
        ./crash-worker.sh 0
        sleep 0.2
        mv /tmp/wallaroo.0 /tmp/wallaroo.0.`date +%s`
        echo -n s0
        ./start-initializer.sh
        poll_out=`poll_ready -w 4 2>&1`
        if [ $? -ne 0 -o ! -z "$poll_out" ]; then
            echo "custom3006 cmd $cmd: $poll_out"
            pause_the_world
            exit 1
        fi
        sleep 1.5
    done
}

run_custom_tcp_crash0 () {
    ## Assume that we are run with `./master-crasher.sh 2 run_custom_tcp_crash0
    ## See 
    sleep 2

    echo -n c0
    ./crash-worker.sh 0
    sleep 0.2
    mv /tmp/wallaroo.0 /tmp/wallaroo.0.`date +%s`

    echo -n s0
    ./start-initializer.sh
    poll_out=`poll_ready -w 4 2>&1`
    if [ $? -ne 0 -o ! -z "$poll_out" ]; then
        echo "custom3006 cmd $cmd: $poll_out"
        pause_the_world
        exit 1
    fi
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
        *grow*)
            cmd="run_grow_shrink_loop $arg"
            echo RUN: $cmd
            $cmd &
            ;;
        *shrink*)
            cmd="run_grow_shrink_loop $arg"
            echo RUN: $cmd
            $cmd &
            ;;
        run_custom*)
            cmd="$arg"
            echo RUN: $cmd
            $cmd &
            ;;
    esac
done

if [ $run_sanity = true ]; then
    run_sanity_loop &
fi

echo Done, yay ... waiting
wait
exit 0
