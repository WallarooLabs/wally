#!/bin/sh

DESIRED=$1
if [ -z "$DESIRED" ]; then
    usage=yes
elif [ "$DESIRED" -lt 1 ]; then
    usage=yes
else
    usage=no
fi
if [ $usage = yes ]; then
    echo "Usage: $0 num-desired [crash options...]"
    exit 1
fi
shift

START_TIME=$(date +%s000)

if [ -z "$WALLAROO_INIT_HOST" ]; then
    echo "ERROR: please set vars in sample-env-vars.sh.tcp-source+sink or in"
    echo "       sample-env-vars.sh file before running this script"
    exit 1
fi

export PATH=.:$PATH
export PYTHONPATH=$WALLAROO_TOP/machida/lib:$WALLAROO_TOP/examples/python/celsius_connectors:$PYTHONPATH
export WALLAROO_BIN=$WALLAROO_TOP/examples/pony/passthrough/passthrough
export WALLAROO_THRESHOLDS='*.8'

export SENDER_OUTFILE=/tmp/sender.out
export STATUS_CRASH_WORKER=/tmp/crasher.worker.doit
export STATUS_CRASH_SINK=/tmp/crasher.sink.doit

reset () {
    reset.sh
    ps axww | grep master-crasher.sh | grep -v $$ | awk '{print $1}' | xargs kill -9 > /dev/null 2>&1
    stop_sink > /dev/null 2>&1
    stop_sender > /dev/null 2>&1
}

start_sink () {
    if [ "$WALLAROO_TCP_SOURCE_SINK" = "true" ]; then
        $WALLAROO_TOP/utils/data_receiver/data_receiver \
            --listen 0.0.0.0:$WALLAROO_OUT_PORT --ponythreads=1 \
            >> /tmp/sink-out/output 2>&1 &
    else
        $WALLAROO_TOP/testing/correctness/tests/aloc_sink/aloc_sink /tmp/sink-out/output /tmp/sink-out/abort 7200 >> /tmp/sink-out/stdout-stderr 2>&1 &
    fi
}

stop_sink () {
    if [ "$WALLAROO_TCP_SOURCE_SINK" = "true" ]; then
        ps axww | grep -v grep | grep data_receiver | awk '{print $1}' | xargs kill -9
    else
        ps axww | grep python | grep aloc_sink | awk '{print $1}' | xargs kill -9
    fi
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

print_duration () {
    END_TIME=$(date +%s000)
    echo End time: $END_TIME
    RUN_DURATION=$(($END_TIME - $START_TIME))
    echo Duration: $RUN_DURATION
}

pause_the_world () {
    killall -STOP passthrough
    if [ `uname -s` = Linux ]; then
        print_duration
        killall -STOP master-crasher.sh
    fi
    if [ `uname -s` = Darwin ]; then
        print_duration
        ps axww | grep -v grep | grep '/bin/sh ./master-crasher.sh' | \
            awk '{print $1}' | xargs kill -STOP
    fi
}

start_all_workers () {
    start_initializer -n $DESIRED
    sleep 1
    DESIRED_1=`expr $DESIRED - 1`
    if [ $DESIRED_1 -ge 1 ]; then
        for i in `seq 1 $DESIRED_1`; do
            start_worker -n $DESIRED $i
            sleep 1
        done
    fi
    poll_ready -a -v -w 5 || exit 1
}

start_senders () {
    rm -f $SENDER_OUTFILE.*
    if [ -z "$MULTIPLE_KEYS_LIST" ]; then
        echo ERROR: The variable \$MULTIPLE_KEYS_LIST is empty, exiting!
        exit 1
    fi
    for i in $MULTIPLE_KEYS_LIST; do
        while [ 1 ]; do
            if [ "$WALLAROO_TCP_SOURCE_SINK" = "true" ]; then
                $WALLAROO_TOP/testing/tools/fixed_length_message_blaster/fixed_length_message_blaster \
                --host localhost:$WALLAROO_IN_BASE --file /tmp/input-file.$i.txt \
                --msg-size 53 --batch-size 6 \
                --msec-interval 5 --report-interval 1000000 --ponythreads=1 \
                >> $SENDER_OUTFILE.$i 2>&1
            else
                env ERROR_9_SHOULD_EXIT=true $WALLAROO_TOP/testing/correctness/scripts/effectively-once/at_least_once_line_file_feed /tmp/input-file.$i.txt 66000 >> $SENDER_OUTFILE.$i 2>&1
            fi
            sleep 0.1
        done &
    done
    wait
}

stop_sender () {
    if [ "$WALLAROO_TCP_SOURCE_SINK" = "true" ]; then
        ps axww | grep -v grep | grep fixed_length_message_blaster | awk '{print $1}' | xargs kill > /dev/null 2>&1
    else
        ps axww | grep -v grep | grep at_least_once_line_file_feed | awk '{print $1}' | xargs kill > /dev/null 2>&1
    fi
}

random_float () {
    python -c 'import random; import math; print (random.random() * '$1')'
}

random_int () {
    python -c 'import random; import math; print math.trunc(random.random() * '$1')'
}

random_sleep () {
  (
    base=`random_float $1`
    if [ -z "$2" ]; then
        extra=0.0
    else
        extra=$2
    fi
    sleep `python -c "print $base + $extra"`
  ) > /dev/null 2>&1
}

crash_sink () {
    stop_sink
}

crash_worker () {
    worker="$1"
    if [ -z "$worker" ]; then
        echo ERROR: $0: worker number not given
        print_duration
        exit 1
    fi
    crash-worker.sh $worker
}

run_crash_sink_loop () {
    sleep 3 # Don't start crashing until checkpoint #1 is complete.
    #for i in `seq 1 1`; do
    while [ 1 ]; do
        if [ -f $STATUS_CRASH_SINK ]; then
            /bin/echo -n cS
            crash_sink
            random_sleep 2
            /bin/echo -n rS
            start_sink
            random_sleep 10 5
        else
            /bin/echo -n ":s"
            sleep 1
        fi
    done
}

run_crash_worker_loop () {
    worker="$1"
    suffix="$2"

    if [ -z "$worker" ]; then
        echo ERROR: $0: worker number not given
        print_duration
        exit 1
    fi
    sleep 2 # Don't start crashing until checkpoint #1 is complete.
    counter=0
    while [ 1 ]; do
        counter=`expr $counter + 1`
        if [ -f $STATUS_CRASH_WORKER ]; then
            case "$suffix" in
                *slow*)
                    ## Space apart the crashes very roughly 120+fudge seconds apart
                    if [ $counter -lt 120 ]; then
                        sleep 1
                        sleep `random_float 0.2`
                        continue
                    fi
                    counter=0
                ;;
            esac
            sleep `random_float 4.5`
            /bin/echo -n "c$worker"
            crash_out=`crash_worker $worker`
            mv /tmp/wallaroo.$worker /tmp/wallaroo.$worker.`date +%s` && gzip /tmp/wallaroo.$worker.`date +%s` > /dev/null 2>&1 &
            if [ -z "$crash_out" ]; then
                sleep `random_float 2.5`
                if [ $worker -eq 0 ]; then
                    start_initializer
                else
                    start_worker $worker
                fi
                /bin/echo -n "r$worker"
                sleep 0.25
            else
                echo "Crash of $worker failed: $crash_out"
                pause_the_world
                break
            fi
        else
            /bin/echo -n ":c$worker"
            sleep 1
        fi
        poll_out=`poll_ready -w 4 2>&1`
        status=$?
        if [ $status -ne 0 -o ! -z "$poll_out" ]; then
            echo "CRASH LOOP A: $worker: exit $status reason $poll_out"
            rm -f $STATUS_CRASH_WORKER
            rm -f $STATUS_CRASH_SINK
            sleep 7
            poll_out=`poll_ready -w 4 -a -S -A 2>&1`
            status=$?
            if [ $status -ne 0 -o ! -z "$poll_out" ]; then
                echo "CRASH LOOP B: $worker: pause the world: exit $status reason $poll_out"
                echo "SLEEP: $worker @ 45" ; sleep 45
                pause_the_world
                break
            else
                touch $STATUS_CRASH_WORKER
                touch $STATUS_CRASH_SINK
                echo "CRASH LOOP $worker: resume: $poll_out"
            fi
        fi
    done
}

run_sanity_loop () {
    outfile=/tmp/sanity-loop.out
    while [ 1 ]; do
        sleep 1
        /bin/echo -n ,
        if [ "$WALLAROO_TCP_SOURCE_SINK" = "true" ]; then
            ## verification script's assumptions are not met by TCPSink
            continue
        fi
        egrep 'ERROR|FATAL|CRIT' /tmp/sink-out/stdout-stderr
        if [ $? -eq 0 ]; then
            echo SANITY
            break
        fi
        multi_key_tmp_file=/tmp/concat-multikey-tmp-file
        rm -f $multi_key_tmp_file
        errors=0
        for i in $MULTIPLE_KEYS_LIST; do
            ./1-to-1-passthrough-verify.sh $i /tmp/input-file.$i.txt $multi_key_tmp_file > $outfile 2>&1
            if [ $? -ne 0 ]; then
                echo ""
                head $outfile
                rm $outfile
                echo SANITY2
                errors=1
            fi
            rm $outfile
        done
        if [ $errors -ne 0 ]; then
            print_duration
            pause_the_world
        fi
        total=0
        found=0
        for i in $MULTIPLE_KEYS_LIST; do
            total=`expr $total + 1`
            res=`logtail $SENDER_OUTFILE.$i | egrep 'MultiSourceConnector closed Stream.*, point_of_ref=12368928, is_open=False'`
            if [ ! -z "$res" ]; then
                found=`expr $found + 1`
            fi
        done
        if [ $found -eq $total ]; then
            echo "SANITY LOOP SUCCESS: EOF found!"
            echo "SANITY LOOP SUCCESS: EOF found!" >> /tmp/res
            print_duration
            echo $res >> /tmp/res
            pause_the_world
        fi
    done
    echo "SANITY LOOP FAILURE: pause the world"
    print_duration
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
                    /bin/echo -n "Join $w."
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
                    /bin/echo -n "Shrink $running"
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
            ## /bin/echo -n Shrink-$CUSTOM_SHRINK_MANY
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

    /bin/echo -n "Shrink worker2"
    shrink_worker 2
    sleep 2

    /bin/echo -n "Join worker2 again"
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
        /bin/echo -n "Join worker$i"
        join_worker $i
        sleep 1
    done

    /bin/echo -n "Shrink worker7"
    shrink_worker 7
    sleep 2

    /bin/echo -n "Join worker7 again"
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
        /bin/echo -n "Shrink worker$i"
        shrink_worker $i
        sleep 1
        poll_out=`poll_ready -w 4 2>&1`
        if [ $? -ne 0 -o ! -z "$poll_out" ]; then
            echo "custom4 shrinking worker$i: $poll_out"
            pause_the_world
            print_duration
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
            /bin/echo -n $cmd
            $cmd
            sleep 1
            poll_out=`poll_ready -w 4 2>&1`
            if [ $? -ne 0 -o ! -z "$poll_out" ]; then
                echo "custom5 cmd $cmd: $poll_out"
                pause_the_world
                print_duration
                exit 1
            fi
            sleep 1.5
        done
    done
    /bin/echo -n "join_worker 3"
    join_worker 3
    sleep 3
}

run_custom3006 () {
    ## Assume that we are run with `./master-crasher.sh 2 run_custom306`
    ## See https://github.com/WallarooLabs/wallaroo/issues/3006
    sleep 2

    while [ 1 ]; do
        /bin/echo -n c0
        ./crash-worker.sh 0
        sleep 0.2
        new=/tmp/wallaroo.0.`date +%s`
        mv /tmp/wallaroo.0 $new && gzip $new &
        /bin/echo -n s0
        ./start-initializer.sh
        poll_out=`poll_ready -w 4 2>&1`
        if [ $? -ne 0 -o ! -z "$poll_out" ]; then
            echo "custom3006 cmd $cmd: $poll_out"
            pause_the_world
            print_duration
            exit 1
        fi
        sleep 1.5
    done
}

run_custom_tcp_crash0 () {
    ## Assume that we are run with `./master-crasher.sh 2 run_custom_tcp_crash0
    sleep 4

    /bin/echo -n c0
    ./crash-worker.sh 0
    sleep 0.2
    mv /tmp/wallaroo.0 /tmp/wallaroo.0.`date +%s`

    /bin/echo -n s0
    ./start-initializer.sh
    poll_out=`poll_ready -w 4 2>&1`
    if [ $? -ne 0 -o ! -z "$poll_out" ]; then
        echo ""
        echo "\nQuery initializer\n"
        ../../../../testing/tools/external_sender/external_sender -e 127.0.0.1:7103 -t cluster-status-query
        echo "\nQuery worker1\n"
        ../../../../testing/tools/external_sender/external_sender -e 127.0.0.1:7113 -t cluster-status-query
        echo "\nQuery initializer again\n"
        ../../../../testing/tools/external_sender/external_sender -e 127.0.0.1:7103 -t cluster-status-query
        pause_the_world
        print_duration
        exit 1
    fi
}

run_custom_crashsink_crash0_overlap () {
    ## Assume that we are run with `./master-crasher.sh 3 run_custom_crashsink_crash0_overlap`
    sleep 4

    /bin/echo -n cS
    crash_sink
    sleep 0.1

    /bin/echo -n c0
    ./crash-worker.sh 0
    mv /tmp/wallaroo.0 /tmp/wallaroo.0.`date +%s`
    sleep 0.1

    /bin/echo -n rS
    start_sink
    sleep 0.1

    /bin/echo -n s0
    ./start-initializer.sh
    poll_out=`poll_ready -w 4 2>&1`
    if [ $? -ne 0 -o ! -z "$poll_out" ]; then
        echo ""
        echo "\nQuery initializer\n"
        ../../../../testing/tools/external_sender/external_sender -e 127.0.0.1:7103 -t cluster-status-query
        echo "\nQuery worker1\n"
        ../../../../testing/tools/external_sender/external_sender -e 127.0.0.1:7113 -t cluster-status-query
        echo "\nQuery worker2\n"
        ../../../../testing/tools/external_sender/external_sender -e 127.0.0.1:7123 -t cluster-status-query
        echo "\nQuery initializer again\n"
        ../../../../testing/tools/external_sender/external_sender -e 127.0.0.1:7103 -t cluster-status-query
        echo "SLEEP 10"; sleep 10
        pause_the_world
        print_duration
        exit 1
    fi
}

run_custom_20191210a () {
    ## Assume that we are run with `./master-crasher.sh 2 run_custom_20191210a`

    while [ 1 ]; do
        (
            sleep 4.9
            /bin/echo -n c0
            crash_worker 0
            mv /tmp/wallaroo.0 /tmp/wallaroo.0.`date +%s` && gzip /tmp/wallaroo.0.`date +%s` > /dev/null 2>&1 &
            sleep 0.9
            /bin/echo -n r0
            start_initializer
        ) &
        (
            sleep 3.7
            /bin/echo -n cS
            crash_sink
            sleep 1.0
            /bin/echo -n rS
            start_sink
        ) &
        wait
        /bin/echo -n echo both-done.
        poll_out=`poll_ready -w 4 2>&1`
        if [ $? -ne 0 -o ! -z "$poll_out" ]; then
            echo "BUMMER A: pause the world: $poll_out"
            poll_out=`poll_ready -w 4 2>&1`
            if [ $? -ne 0 -o ! -z "$poll_out" ]; then
                echo "BUMMER B: pause the world: $poll_out"
                pause_the_world
                break
            fi
        fi
        sleep 10
    done
}

touch $STATUS_CRASH_WORKER
touch $STATUS_CRASH_SINK
reset
start_sink ; sleep 1
start_all_workers
start_senders &

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
            worker=`echo $arg | sed -e 's/crash//' -e 's/\..*//'`
            suffix=""
            case $arg in
                *.*)
                    suffix=`echo $arg | sed 's/crash[0-9]*\.//'`
                ;;
            esac
            cmd="run_crash_worker_loop $worker $suffix"
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

echo Start time: $START_TIME
echo Done, yay ... waiting
wait > /dev/null 2>&1
print_duration
exit 0
