# Wallaroo Command-Line Options

Every Wallaroo option exposes a set of command-line options that are used to configure it. This document gives an overview of each of those options.

## Command-Line Parameters

When running a Wallaroo application, we use some of the following command line parameters (a star indicates it is required, a plus that it is required for multi-worker runs):

```bash
  --control/-c +[Sets address for initializer control channel; sets
    control address to connect to for non-initializers]
  --data/-d +[Sets address for initializer data channel]
  --my-control [Optionally sets address for my data channel]
  --my-data [Optionally sets address for my data channel]
  --phone-home/-p [Sets address for phone home connection]
  --external/-e [Sets address for external message channel]
  --worker-count/-w +[Sets cluster initialier's total number of workers,
    including cluster initializer itself]
  --name/-n +[Sets name for this worker]

  --metrics/-m [Sets address for external metrics (e.g. monitoring hub)]
  --cluster-initializer/-t [Sets this process as the cluster
    initializing process (that status is meaningless after init is done)]
  --resilience-dir/-r [Sets directory to write resilience files to,
    e.g. -r /tmp/data (no trailing slash)]
  --log-rotation [Enables log rotation. Default: off]
  --event-log-file-size/-l [Optionally set a file size for triggering
    event log file rotation. If no file size is set, log rotation is only
    triggered by external control messages sent to the address used with
    --external]

  --join/j [When a new worker is joining a running cluster, pass the
    control channel address of any worker as the value for this
    parameter]
  --stop-world/u [Sets pause before state migration after the stop the
    world]
```

Wallaroo currently supports one source per pipeline, which is setup by the application code. Each pipeline may have at most one sink, which also setup by the application code.

In order to monitor metrics, the target address for metrics data should be defined via the `--metrics/-m` parameter, using a `host:port` format (e.g. `127.0.0.1:5002`).

## Machida specific parameters

In addition to the Wallaroo command line paramters, Machida, the python-wallaroo interface, takes the additional argument

```bash
  --application-module [Specify the Machida application module]
```

`--application-module` specifies the _name_ that machida will attempt to import as the Python Wallaroo application file. For example, if you write a Python Wallaroo application and save it as `my_application.py`, then you should provide that name to machida as `--application-module my_application`.

### Multi-Worker Setup

A Wallaroo application can be distributed over multiple Wallaroo processes, or "workers". When a Wallaroo application first spins up, one of these workers plays the role of the "initializer", a temporary role that only has significance during initialization (after that, the cluster is decentralized).

We specify that a worker will play the role of initializer via the `--cluster-initializer` flag. We specify the total number of workers at startup (including the initializer) via the `--worker-count` parameter.

Workers communicate with each other over two channels: a control channel and a data channel. We need to tell every worker which addresses the initializer is listening on for each of these channels. `--control` specifies the initializer's control address and `--data` specifies the initializer's data address.

Remember that multi-worker runs require that you distribute the same binary to all machines that are involved. Attempting to connect different binaries into a multi-worker cluster will fail.

#### Example Single-Worker Run

In order to run a single worker for a Wallaroo app, we need to provide the input and output addresses for the TCPSource and TCPSink (`--in` and `--out`, which will be handled by the application setup code), and the metrics target address (`--metrics`). For example, using the Celsius Converter application (after navigating to `examples/pony/celsius` and compiling) we would run:

```bash
./celsius --in 127.0.0.1:6000 --out 127.0.0.1:5555 --metrics 127.0.0.1:5001
```

#### Example Multi-Worker Run

Sticking with our Celsius Converter app, here is an example of how you might run it over two workers. In addition to the parameters specified in the last section, we need to specify the control channel address (`--control`), data channel address (`--data`), number of workers (`--worker-count`), and, for the initializer process, the fact that it is the cluster initializer (`--cluster-initializer` flag):

*Worker 1*

```bash
./celsius --in 127.0.0.1:6000 --out 127.0.0.1:5555 --metrics 127.0.0.1:5001 \
--control 127.0.0.1:6500 --data 127.0.0.1:6501 --worker-count 2 \
--clutser-initializer
```

*Worker 2*

```bash
./celsius --in 127.0.0.1:6000 --out 127.0.0.1:5555 --metrics 127.0.0.1:5001 \
--control 127.0.0.1:6500 --name Worker2
```

These example commands assume that both workers are run on the same machine. To run each worker on a separate machine you must use the appropriate IP address or hostname for each worker.

NOTE: Currently, worker 1 is automatically assigned the name "initializer" no matter what name you give it via the command line.

### Resilience

If resilience is turned on, you can optionally specify the target directory for resilience files via the `--resilience-dir/-r` parameter (default is `/tmp`), and whether or not log should be rotated (`--log-rotation`, off by default). If log rotation is enabled, you may also set the file size on which to trigger log rotation (per worker, in bytes). If no file size is set, log rotation will only happen if it is requested via an external control channel message sent to the address specified in the cluster intializer worker's `--external` parameter. If a file size _is_ set, log rotation may trigger if either the log file reaches the specified file size, or if a log rotation is requested for the worker via the external control channel.

## Performance Flags

You can specify how many threads a Wallaroo process will use via the following
argument:

```bash
--ponythreads=4
```

If you do not specify the number of `ponythreads`, the process will try to use all available cores.

There are additional performance flags`--ponypinasio` and `--ponynoblock` that can be used as part of a high-performance configuration. Documentation on how to configure for best performance is coming soon.
