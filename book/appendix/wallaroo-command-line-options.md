# Wallaroo Command-Line Options

Every Wallaroo option exposes a set of command-line options that are used to configure it. This document gives an overview of each of those options.

## Command-Line Parameters

When running a Wallaroo application binary, we use some of the following command line parameters (a star indicates it is required, a plus that it is required for multi-worker runs):

```
      --in/-i *[Comma-separated list of input addresses sources listen on]
      --out/-o *[Sets address for sink outputs]
      --control/-c +[Sets address for control channel]
      --data/-d +[Sets address for data channel]
      --worker-count/-w +[Sets total number of workers, including topology
        initializer]
      --worker-name/-n +[Sets name for this worker]
      --metrics/-m [Sets address for external metrics (e.g. monitoring hub)]
      --cluster-initializer/-t [Flag that sets this process as the
        initializer]
      --resilience-dir/-r [Sets directory to write resilience files to,
        e.g. -r /tmp/data (no trailing slash)]
      --ponythreads [Number of application threads. Used as part of a high-performance configuration.]
      --ponypinasio [Used as part of a high-performance configuration.]
      --ponynoblock [Used as part of a high-performance configuration.]
```

Wallaroo currently supports one input stream per pipeline. We provide comma-separated IP addresses for TCP source listeners via the `--in` parameter. Currently, the order of these addresses corresponds to the order in which pipelines are defined in your application code.

Wallaroo currently supports one sink per app. Use the `--out` parameter to specify the address that this sink will write out to over TCP.

In order to monitor metrics, we must specify the target address for metrics data via the `--metrics` parameter.

### Multi-Worker Setup

A Wallaroo application can be distributed over multiple Wallaroo processes, or "workers". When a Wallaroo application first spins up, one of these workers plays the role of the "initializer", a temporary role that only has significance during initialization (after that, the cluster is decentralized).

We specify that a worker will play the role of initializer via the `--cluster-initializer` flag. We specify the total number of workers at startup (including the initializer) via the `--worker-count` parameter.

Workers communicate with each other over two channels, a control channel and a data channel. We need to tell every worker which addresses the initializer is listening on for each of these channels. `--control` specifies the initializer's control address and `--data` specifies the initializer's data address.

Remember that multi-worker runs require that you distribute the same binary to all machines that are involved. Attempting to connect different binaries into a multi-worker cluster will fail.

#### Example Single-Worker Run

In order to run a single worker for a Wallaroo app, we need to specify the input address (`-i`), the target output address (`-o`), and the metrics target address (`-m`). For example, using the Celsius Converter application (after navigating to `examples/pony/celsius` and compiling) we would run:

```bash
./celsius -i 127.0.0.1:6000 -o 127.0.0.1:5555 -m 127.0.0.1:5001
```

#### Example Multi-Worker Run

Sticking with our Celsius Converter app, here is an example of how you might run it over two workers. Beyond the parameters specified in the last section, we need to specify the control channel address (`-c`), data channel address (`-d`), number of workers (`-w`), and, for the initializer process, the fact that it is the cluster initializer (`-t` flag):

*Worker 1*

```bash
./celsius -i 127.0.0.1:6000 -o 127.0.0.1:5555 -m 127.0.0.1:5001 \
-c 127.0.0.1:6500 -d 127.0.0.1:6501 -w 2 -t
```

*Worker 2*

```bash
./celsius -i 127.0.0.1:6000 -o 127.0.0.1:5555 -m 127.0.0.1:5001 \
-c 127.0.0.1:6500 -n Worker2
```

These example commands assume that both workers are run on the same machine. To run each worker on a separate machine you must use the appropriate IP address or hostname for each worker.

NOTE: Currently, worker 1 is automatically assigned the name "initializer" no matter what name you give it via the command line.

### Resilience

If [resilience is turned on](/book/core-concepts/resilience.md), you can optionally specify the target directory for resilience files via the `--resilience-dir/-r` parameter (default is `/tmp`).

## Performance Flags

You can specify how many threads a Wallaroo process will use via the following
argument:

```bash
--ponythreads=4
```

If you do not specify the number of `ponythreads`, the process will try to use all available cores.

There are additional performance flags`--ponypinasio` and `--ponynoblock` that can be used as part of a high-performance configuration. Documentation on how to configure for best performance is coming soon.
