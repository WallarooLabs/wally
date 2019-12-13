
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

## Build prerequisites

* I've only run this stuff on Linux, but the scripts have now been
  adapted to work (I believe) on MacOS.

    * I've been using an Ubuntu Xenial/16.04 LTS virtual machine with
      2 virtual CPUs and 4GB RAM.

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
export WALLAROO_BIN=$HOME/wallaroo/examples/pony/passthrough/passthrough
    or else
export WALLAROO_BIN=$WALLAROO_TOP/examples/pony/passthrough/passthrough

export WALLAROO_THRESHOLDS='*.8' # Turns on verbose logging @ debug level
```

Finally, all of the Bourne/Bash shell variables in the
`sample-env-vars.sh` file must be defined by using:

```
. ./sample-env-vars.sh
    or else
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
poll-ready.sh -v -a
```

### Start an N-worker Wallaroo cluster

The naming convention for the workers is:

- 1st: `initializer`
- 2nd: `worker1`
- 3rd: `worker2`
- ...etc...

WARNING: DO NOT USE THE `start-worker.sh` script to start
non-`initializer` workers for the first time.

The `sleep` commands are recommended: Wallaroo isn't 100% robust to
a worker joining very close in time to another worker's start.

Let's start a 4-worker cluster by first starting `initializer` and
then starting `worker1` through `worker3`.

```
DESIRED=4
./start-initializer.sh -n $DESIRED
sleep 1
DESIRED_1=`expr $DESIRED - 1`
for i in `seq 1 $DESIRED_1`; do ./start-worker.sh -n $DESIRED $i; sleep 1; done
./poll-ready.sh -v -a
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
sleep 1
./poll-ready.sh -v -a
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
for i in `seq 5 8`; do ./join-worker.sh -n 4 $i; sleep 1; done
./poll-ready.sh -v -a
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
./poll-ready.sh -v -a
```

### Crash worker `N`

NOTE: This script extends the naming scheme to allow the argument `0`
to mean the `initializer` worker.

Let's crash `initializer`.

```
./crash-worker.sh 0
sleep 1
./poll-ready.sh -v -a
```

### Restart the `initializer` after a crash

```
./start-initializer.sh
```

### Restart worker `N` instead of `initializer` after a crash

Let's restart 1 worker, `worker5`.

```
./start-worker.sh -n 1 5
```


## Testing Recipes

### Prerequisites

Create a large input file, approx 12MB, using the commands:

```
./remove-input-files.sh
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
* Be sure to run `poll-ready.sh -a -v` to verify that all workers are ready for work.

In Window 2:

```
env PYTHONPATH=$WALLAROO_TOP/machida/lib:examples/python/celsius_connectors $WALLAROO_TOP/testing/correctness/scripts/effectively-once/at_least_once_line_file_feed /tmp/input-file.A.txt 21222 |& tee /tmp/feed.out
```

In Window 1:

```
while [ 1 ]; do ./1-to-1-passthrough-verify.sh A /tmp/input-file.A.txt  ; if [ $? -ne 0 ]; then killall -STOP passthrough; echo STOPPED; break; fi ; sleep 1; done
```

### Repeatedly crashing and restarting the sink

TODO replace hack

```
for i in `seq 1 100`; do ps axww | grep aloc_sink | grep -v grep | awk '{print $1}' | xargs kill ; amount=`date | sed -e 's/.*://' -e 's/ .*//'`; echo i is $i, amount is $amount; sleep 2.$amount ; env PYTHONPATH=$WALLAROO_TOP/machida/lib $WALLAROO_TOP/testing/correctness/tests/aloc_sink/aloc_sink /tmp/sink-out/output /tmp/sink-out/abort 7200 >> /tmp/sink-out/stdout-stderr 2>&1 & sleep 2 ; ./1-to-1-passthrough-verify.sh A /tmp/input-file.A.txt ; if [ $? -eq 0 ]; then echo OK; else killall -STOP passthrough ; echo STOPPED; break; fi ; egrep -v 'DEBUG|INFO' /tmp/sink-out/stdout-stderr ; if [ $? -eq 0 ]; then killall -STOP passthrough ; echo STOP-grep; break; fi; done
```

### Repeatedly crashing and restarting a non-initializer worker

TODO replace hack

```
TO_CRASH=1
for i in `seq 1 100`; do echo -n $i; crash-worker.sh $TO_CRASH ; sleep 0.2 ; mv /tmp/wallaroo.$TO_CRASH /tmp/wallaroo.$TO_CRASH.$i ; gzip -f /tmp/wallaroo.$TO_CRASH.$i & start-worker.sh $TO_CRASH ; sleep 1.2; poll-ready.sh -w 2 -a; if [ $? -ne 0 ]; then echo BREAK0; break; fi; egrep 'ERROR|FATAL|CRIT' /tmp/sink-out/stdout-stderr ; if [ $? -eq 0 ]; then echo BREAK; break; fi; ./1-to-1-passthrough-verify.sh A /tmp/input-file.A.txt; if [ $? -ne 0 ]; then echo BREAK2; break; fi ;sleep 0.2; done
```

### Repeatedly crashing and restarting the initializer worker

TODO replace hack

NOTE: There's a limitation in the Python connector client
w.r.t. reconnecting after a close.  Read below for more detail.

```
for i in `seq 1 100`; do echo -n $i; crash-worker.sh 0 ; sleep 0.2 ; mv /tmp/wallaroo.0 /tmp/wallaroo.0.$i ; gzip -f /tmp/wallaroo.0.$i & start-initializer.sh ; sleep 1.2; poll-ready.sh -w 2 -a; if [ $? -ne 0 ]; then echo BREAK0; break; fi; egrep 'ERROR|FATAL|CRIT' /tmp/sink-out/stdout-stderr ; if [ $? -eq 0 ]; then echo BREAK; break; fi; ./1-to-1-passthrough-verify.sh A /tmp/input-file.A.txt; if [ $? -ne 0 ]; then echo BREAK2; break; fi ;sleep 0.2; done
```

The Python connector client is not 100% reliable in reconnecting to
Wallaroo when the Wallaroo worker that it is connected to crashes.
(This kind of crash is handled different by the `asynchat` framework
than when a RESTART message is received.)

I recommend using a `while [ 1 ]; ... done` loop (or equivalent) to
restart the `at_least_once_line_file_feed` script.

### Repeatedly crashing and restarting the source

TODO replace hack

```
while [ 1 ]; do env PYTHONPATH=$WALLAROO_TOP/machida/lib:$WALLAROO_TOP/examples/python/celsius_connectors $WALLAROO_TOP/testing/correctness/scripts/effectively-once/at_least_once_line_file_feed /tmp/input-file.A.txt 41000 & amount=`date | sed -e 's/.*://' -e 's/ .*//'`; echo amount is $amount; sleep 1.$amount ; kill -9 `ps axww | grep -v grep | grep feed | awk '{print $1}'`; sleep 0.$amount; done
```
