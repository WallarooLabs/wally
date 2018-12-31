# Sleepy Python

## About The Application

This is a benchmark application that is used for testing the plumbing of a cluster's horizontal scaling properties. It uses busy sleeping to force Python to hold onto the GIL while blocking.

## Input

The inputs for this are 1KiB "nonces" which are generated in gen.py. Most of the data is ignored but there is a 32bit value read to control partitioning. The generator uses a uniform distribution over a multiple of 60 to keep things as balanced as possible amoung many common cluster sizes.

## Output

The pipeline is not currently configured to write any output but there is an optional "ok" sink result can be added easily when you need to confirm that flow is reaching the sink.

## Delay Configuration

There is a delay parameter that is used to configure processing time of a single stateful step. This defaults to 0ms which helps give a baseline overhead for the pipeline.

## Running Sleepy Python

In order to run the application you will need Machida, Giles Sender, and the Cluster Shutdown tool.

### Setting up the Metrics UI

We're assuming the metrics UI application is running. You may use docker or a manually started instance. We expect it to be reachable on localhost with it's default metrics collection port of 5001. Adjust the examples below as necessary

### Setting up the Sink

Since we don't usually care about the output here, the simplest sink would be netcat to /dev/null:

```bash
nc -l 127.0.0.1 7002 > /dev/null
```

### Setting up Machida to run the Wallaroo application

Machida should have the proper PYTHON path setup to include a copy of the wallaroo module. The machida program should be in the path as well, otherwise you can use the relative build path:

```bash
machida --application-module sleepy \
  --delay_ms 5
  --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --worker-name worker1 --external 127.0.0.1:5050 --cluster-initializer \
  --ponythreads=1 --ponynoblock
```

Adjust the delay (in milliseconds) as needed.

### Setting up the Source

There are a few ways to send data but we're expecting that the giles sender application be used to control flow rate during benchmarks in this case.

```bash
giles/sender/sender  --host 127.0.0.1:7010 \
  --file testing/performance/apps/python/sleepy_python/_nonces.bin \
  --batch-size 20 --interval 100_000 --messages 1024 --msg-size 1028 \
  --binary --repeat --ponythreads=1 --ponynoblock
```

Alternatively you can use a program of your choice (`nc` for example) to send data as needed. Be advised that you'll have implement your own flow control here.

## Shutdown

To shutdown the cluster, use the cluster_shutdown utility with the proper cluster control port. Using the same port we provided in the example above, that would be:

```bash
cluster_shutdown 127.0.0.1:5050
```

You can shut down Giles Sender by pressing `Ctrl-c` from its shell.
