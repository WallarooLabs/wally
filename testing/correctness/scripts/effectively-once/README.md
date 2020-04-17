
# Usage notes, tips, etc.

This doc assumes that your login shell is either the Bourne shell or the Bash
shell.

Also, we assume that the value of the environment variable
`WALLAROO_TOP` is set correctly; please follow the advice below.

These scripts were originally designed to test the Wallaroo connector
protocol sources and sinks.  Later, they were retrofitted to be able
to test plain TCP sources and sinks also.  To test TCP source and
sinks, the `WALLAROO_TCP_SOURCE_SINK` environment variable must be set
to `true`.

The order of presentation for major sections of this document are:

* How to build
* Basics about how to stop & start clusters, crash & restart workers, etc.
    * For most use cases, I expect that you'd use the `master-crasher.sh` script for managing the entire testing lifecycle.
* How to run & test clusters using a high-level automated script ("`master-crasher.sh`")
    * This is my recommended method for testing.
* How to run & test clusters using low-level shell scripts ("Testing Recipes")
    * These scripts were designed for higher-level orchestration, by something like the `master-crasher.sh` script.  They are a bit cumbersome to use manually, but I've found them to be useful on rare occasions.


## Build prerequisites

* I've only run this stuff on Linux, but the scripts have now been
  adapted to work (I believe) on MacOS.

    * I've been using an Ubuntu Xenial/16.04 LTS virtual machine with
      2 virtual CPUs and 4GB RAM.

* Include this directory in your `PATH`:

```
export PATH=${PATH}:.
```

* You'll need the `logtail` utility installed.  Download
  https://github.com/kadashu/logtail/blob/master/logtail and put it
  into your $PATH somewhere (MacOS) or install with `apt install logtail` (Linux).

* Docker on the Linux host.  Start the metrics UI app via the
  following command, and aim a Web browser at http://linux-ip-addr:4000/.

```
sudo docker kill mui; sudo docker rm mui; sudo docker run -d -u root --privileged  -v /usr/bin:/usr/bin:ro   -v /var/run/docker.sock:/var/run/docker.sock -v /bin:/bin:ro  -v /lib:/lib:ro  -v /lib64:/lib64:ro  -v /usr:/usr:ro  -v /tmp:/apps/metrics_reporter_ui/log  -p 0.0.0.0:4000:4000 -p 0.0.0.0:5001:5001 --name mui -h mui --net=host wallaroolabs/wallaroo-metrics-ui:0.4.0
```

* Build the Wallaroo app & related utilities.

```
make -C ../../../.. \
    PONYCFLAGS="--verbose=1 -d -Dresilience -Dtrace -Dcheckpoint_trace -Didentify_routing_ids" \
    build-examples-pony-passthrough build-testing-tools-external_sender \
    build-utils-cluster_shrinker build-utils-data_receiver \
    build-testing-tools-fixed_length_message_blaster
```

## Basic command use

### Prerequisites

The environment variable `WALLAROO_TOP` should be defined to be the
path to the top of your Wallaroo source repo.  If this environment
variable is not set, then the `sample-env-vars.sh` script will define
that variable to be:

```
export WALLAROO_TOP=$HOME/wallaroo
```

The environment variable `WALLAROO_BIN` must contain the path to the
Wallaroo executable that you wish to test.  Also, when additional
logging detail is required, I recommend setting the
`WALLAROO_THRESHOLDS` environment variable as shown below.  For
example:

```
export WALLAROO_BIN=$WALLAROO_TOP/examples/pony/passthrough/passthrough
export WALLAROO_THRESHOLDS='*.8' # Turns on verbose logging @ debug level
```

Finally, all of the Bourne/Bash shell variables in the
`sample-env-vars.sh` file must be defined by using:

```
. ./sample-env-vars.sh
    or else (to use regular TCP sources & sinks instead of effectively-once)
. ./sample-env-vars.sh.tcp-source+sink
```

Their values may be tweaked to fit your use case, hence the prefix
"sample" in the file name.

You can also pass in your Wallaroo top directory directly, e.g. 
```
. ./sample-env-vars.sh path/to/wallaroo
. ./sample-env-vars.sh.tcp-source+sink path/to/wallaroo
```

### Stop all Wallaroo-related processes and delete all state files

```
./reset.sh
```

### Prerequisite: Start Wallaroo's sink

```
export PYTHONPATH=$WALLAROO_TOP/machida/lib
$WALLAROO_TOP/testing/correctness/tests/aloc_sink/aloc_sink /tmp/sink-out/output /tmp/sink-out/abort 7200 > /tmp/sink-out/stdout-stderr 2>&1 &
```

### Start a 1-worker Wallaroo cluster

NOTE: The `poll-ready.sh` script will fail if the sink process is not
already running.

```
./start-initializer.sh -n 1
./poll-ready.sh -v 0
```

### Start an N-worker Wallaroo cluster

The naming convention for the workers is:

- 0th: `initializer`
- 1st: `worker1`
- 2nd: `worker2`
- ...etc...

WARNING: DO NOT USE THE `start-worker.sh` script to start
non-`initializer` workers for the first time.

The `sleep` commands are recommended: Wallaroo isn't 100% robust to
a worker joining very close in time to another worker's start.

Let's start a 4-worker cluster by first starting `initializer` and
then starting `worker1` through `worker3`.

```
./reset.sh
$WALLAROO_TOP/testing/correctness/tests/aloc_sink/aloc_sink /tmp/sink-out/output /tmp/sink-out/abort 7200 > /tmp/sink-out/stdout-stderr 2>&1 &

DESIRED=4
./start-initializer.sh -n $DESIRED
sleep 1
DESIRED_1=`expr $DESIRED - 1`
for i in `seq 1 $DESIRED_1`; do ./start-worker.sh -n $DESIRED $i; sleep 1; done
./poll-all-ready.sh -v
```

### Join a worker to an existing Wallaroo cluster

NOTE: You are specifying which worker to join by name.  Because you
can't join or shrink the `initializer` worker, it isn't eligible to be
started by this script.  Thus specifying `4` as the argument will
start `worker4` and join it to the already-running `initializer`
worker.

Let's join `worker4`.

```
./join-worker.sh -n 1 4
sleep 2
./poll-all-ready.sh -v
```

### Join N workers to an existing Wallaroo cluster

NOTE: See note in "Join a worker to an existing Wallaroo cluster"
above.

WARNING: DO NOT USE THE `join-worker.sh` script to start
non-`initializer` workers for the first time.

The `sleep` commands are recommended: Wallaroo isn't 100% robust to
a worker joining very close in time to another worker's join.

Let's start 4 workers: `worker5` through `worker8`.

```
for i in `seq 5 8`; do ./join-worker.sh -n 4 $i; sleep 2; ./poll-all-ready.sh -v; done
```

### Shrink the cluster by 1 worker

NOTE: This is a helper script that wraps invocation of the
`cluster_shrinker` utility.  It uses the same argument-to-name
convention as the `start-worker.sh` and `join-worker.sh` scripts: if
you specify `6`, then it will shrink away the `worker6` worker.

Let's shrink `worker6`.

```
./shrink-worker.sh 6
sleep 1
./poll-all-ready.sh -v
```

### Crash worker `N`

NOTE: This script extends the naming scheme to allow the argument `0`
to mean the `initializer` worker.

Let's crash `initializer`.

```
./crash-worker.sh 0
sleep 1
./poll-ready.sh -v -w 2 0
```

### Restart the `initializer` after a crash

```
./start-initializer.sh
sleep 1
./poll-ready.sh -v 0
./poll-all-ready.sh ; if [ $? -eq 0 ]; then echo All ready; else echo Bummer; fi
```

### Restart worker `N` instead of `initializer` after a crash

Let's crash & restart 1 worker, `worker5`.

```
./crash-worker.sh 5
sleep 1
./start-worker.sh -n 1 5
sleep 1
./poll-all-ready.sh -v
```


## `master-crasher.sh`

The environment variables found in the [sample-env-vars.sh](sample-env-vars.sh) control many aspects of the total system under test.  This section will mention a few useful variables to experiment with.

The `master-crasher.sh` script is a one-size-fits-many orchestration script that takes care of the following general steps on a single machine.  No special container orchestration or OS features are required.  All processes are assigned non-conflicting TCP ports for use on a single host/virtual machine.

1. Kill all Python processes related to sources & sinks, Wallaroo processes, etc. and delete their related files in `/tmp`.

2. Start the sink, Wallaroo, and source/sender processes to create a Wallaroo cluster of a desired size.
    * TODO SLF LEFT OFF HERE

TODO write up bug where source isn't started @ first step -> Wallaroo Fail().


## Testing Recipes

### Prerequisites

Create a large input file, approx 12MB, using the commands:

```
./delete-input-files.sh
./create-input-files.sh
```

All lines in the `/tmp/input-file.A.txt` file will begin with the letter "A".
The `passthrough` Wallaroo app uses the first character of each line
as the "key" for routing in a multi-worker cluster.  Therefore, all
lines in the file will be processed by the same worker; this property
makes correctness checking easier.  This same beginning-of-line-key-
character convention is used for the files `/tmp/input-file.?.txt`,
where the wildcard represents the key used for all lines in the file.

Note that the metrics UI will only report stats from the worker that
is assigned a routing key; all workers that process no routing keys
will report no activity because they aren't doing any work.

### Run without errors

In Window 1:

* Run `reset.sh`
* Start the Wallaroo cluster with the desired number of workers.
* Be sure to run `poll-all-ready.sh -v` to verify that all workers are ready for work.

In Window 2:

```
env PYTHONPATH=$WALLAROO_TOP/machida/lib:examples/python/celsius_connectors $WALLAROO_TOP/testing/correctness/scripts/effectively-once/at_least_once_line_file_feed /tmp/input-file.A.txt 21222 > /tmp/sender.out 2>&1 &
tail -f /tmp/sender.out | egrep 'acked.*is_open=True'
```

The `tail -f` process is watching for stream ack events.  If the cluster is working correctly, these events should be logged approximately every 1 second.  Stream ack events pause when some part of the Wallaroo cluster (source, Wallaroo worker(s), sink) have crashed and have not been restarted.  After all procs have restarted, the stream ack events should resume.

The input file, `/tmp/input-file.A.txt`, is approximately 12MB in size.  Once the sender has reached the end of the file, the `at_least_once_line_file_feed` process will periodically reconnect and re-send.  This logic is present in cases when new data might be appended to the input file.  Our test procedures does not use this feature.

In Window 3:

```
while [ 1 ]; do /bin/echo -n ,; ./1-to-1-passthrough-verify.sh A /tmp/input-file.A.txt  ; if [ $? -ne 0 ]; then killall -STOP passthrough; echo STOPPED; break; fi ; sleep 1; done
```

### Repeatedly crashing and restarting the sink

This is a long 1-liner that I've used for testing, before `master-crasher.sh` was written.

Prerequisites:

* Start the sink
* Start the Wallaroo cluster of desired size
* Start the `at_least_once_line_file_feed` sender for the `/tmp/input-file.A.txt` file.  Also, monitor with the `is_open=True` loop.

This 1-liner will do the following 100 times:

1. Kill the sink with a combination of `ps`, `grep`, `awk`, and `xargs kill`.
2. Sleep a random amount of time, 2-3 seconds.
3. Restart the sink process.
4. Run the `1-to-1-passthrough-verify.sh` script to verify that no sink data has been lost, duplicated, or re-ordered.

This test should be monitored with the `is_open=True` grep command.  One sign of failure is that `is_open=True` entries are no longer logged; such a failure can indicate that the Stream ID registry has become corrupted, or that a Wallaroo worker has crashed.

```
for i in `seq 1 100`; do ps axww | grep aloc_sink | grep -v grep | awk '{print $1}' | xargs kill ; amount=`date | sed -e 's/.*://' -e 's/ .*//'`; echo i is $i, amount is $amount; sleep 2.$amount ; env PYTHONPATH=$WALLAROO_TOP/machida/lib $WALLAROO_TOP/testing/correctness/tests/aloc_sink/aloc_sink /tmp/sink-out/output /tmp/sink-out/abort 7200 >> /tmp/sink-out/stdout-stderr 2>&1 & sleep 2 ; ./1-to-1-passthrough-verify.sh A /tmp/input-file.A.txt ; if [ $? -eq 0 ]; then echo OK; else killall -STOP passthrough ; echo STOPPED; break; fi ; egrep -v 'DEBUG|INFO' /tmp/sink-out/stdout-stderr ; if [ $? -eq 0 ]; then killall -STOP passthrough ; echo STOP-grep; break; fi; done
```

### Repeatedly crashing and restarting a non-initializer worker

Prerequisites:

* Start the sink
* Start the Wallaroo cluster of desired size
* Start the `at_least_once_line_file_feed` sender for the `/tmp/input-file.A.txt` file.  Also, monitor with the `is_open=True` loop.

This 2-liner will do the following 100 times:

1. Kill the worker named by $TO_CRASH.
2. Sleep a random amount of time, 2-3 seconds.
3. Restart the crashed worker.
4. Run the `1-to-1-passthrough-verify.sh` script to verify that no sink data has been lost, duplicated, or re-ordered.

This test should be monitored with the `is_open=True` grep loop.  See also: previous subsection. In the event of a Wallaroo failure, the output from the crashed/restarted Wallaroo workers is kept in files named `/tmp/wallaroo.$TO_CRASH.{crash iteration number}.`

```
TO_CRASH=1
for i in `seq 1 100`; do echo -n $i; crash-worker.sh $TO_CRASH ; sleep 0.2 ; mv /tmp/wallaroo.$TO_CRASH /tmp/wallaroo.$TO_CRASH.$i ; gzip -f /tmp/wallaroo.$TO_CRASH.$i & start-worker.sh $TO_CRASH ; sleep 1.2; poll-all-ready.sh -w 2; if [ $? -ne 0 ]; then echo BREAK0; break; fi; egrep 'ERROR|FATAL|CRIT' /tmp/sink-out/stdout-stderr ; if [ $? -eq 0 ]; then echo BREAK; break; fi; ./1-to-1-passthrough-verify.sh A /tmp/input-file.A.txt; if [ $? -ne 0 ]; then echo BREAK2; break; fi ;sleep 0.2; done
```

### Repeatedly crashing and restarting the initializer worker

See prerequisites & advice from previous subsection.

WARNING: There's a limitation in the Python connector client
w.r.t. reconnecting after a close.  Read below for more detail.

```
for i in `seq 1 100`; do echo -n $i; crash-worker.sh 0 ; sleep 0.2 ; mv /tmp/wallaroo.0 /tmp/wallaroo.0.$i ; gzip -f /tmp/wallaroo.0.$i & start-initializer.sh ; sleep 1.2; poll-all-ready.sh -w 2; if [ $? -ne 0 ]; then echo BREAK0; break; fi; egrep 'ERROR|FATAL|CRIT' /tmp/sink-out/stdout-stderr ; if [ $? -eq 0 ]; then echo BREAK; break; fi; ./1-to-1-passthrough-verify.sh A /tmp/input-file.A.txt; if [ $? -ne 0 ]; then echo BREAK2; break; fi ;sleep 0.2; done
```

The Python connector client is not 100% reliable in reconnecting to
Wallaroo when the Wallaroo worker that it is connected to crashes.
(This kind of crash is handled different by the `asynchat` framework
than when a RESTART message is received.)

I recommend using a `while [ 1 ]; ... done` loop (or equivalent) to
restart the `at_least_once_line_file_feed` script.

### Repeatedly crashing and restarting the source

See prerequisites & advice from previous subsection.

```
while [ 1 ]; do env PYTHONPATH=$WALLAROO_TOP/machida/lib:$WALLAROO_TOP/examples/python/celsius_connectors $WALLAROO_TOP/testing/correctness/scripts/effectively-once/at_least_once_line_file_feed /tmp/input-file.A.txt 41000 & amount=`date | sed -e 's/.*://' -e 's/ .*//'`; echo amount is $amount; sleep 1.$amount ; kill -9 `ps axww | grep -v grep | grep feed | awk '{print $1}'`; sleep 0.$amount; done
```

