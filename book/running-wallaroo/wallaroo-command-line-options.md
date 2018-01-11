# Wallaroo Command-Line Options

Every Wallaroo option exposes a set of command-line options that are used to configure it. This document gives an overview of each of those options.

## Command-Line Parameters

When running a Wallaroo application, we use some of the following command line parameters (a star indicates it is required, a plus that it is required for multi-worker runs):

```bash
  --control/-c *[Sets address for initializer control channel; sets
    control address to connect to for non-initializers]
  --data/-d *[Sets address for initializer data channel]
  --my-control [Optionally sets address for my data channel]
  --my-data [Optionally sets address for my data channel]
  --external/-e [Sets address for external message channel]
  --worker-count/-w +[Sets cluster initializer\'s total number of workers,
    including cluster initializer itself]
  --name/-n +[Sets name for this worker. Initializer will overwrite this 
    name with "initializer"]

  --metrics/-m *[Sets address for external metrics (e.g. monitoring hub)]
  --cluster-initializer/-t *[Sets this process as the cluster
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

Wallaroo currently supports one source per pipeline, which is setup by the application code. Each pipeline may have at most one sink, which is also set up by the application code.

In order to monitor metrics, the target address for metrics data should be defined via the `--metrics/-m` parameter, using a `host:port` format (e.g. `127.0.0.1:5002`).

## Machida specific parameters

In addition to the Wallaroo command line paramters, Machida, the python-wallaroo interface, takes the additional argument

```bash
  --application-module *[Specify the Machida application module]
```

`--application-module` specifies the _name_ that machida will attempt to import as the Python Wallaroo application file. For example, if you write a Python Wallaroo application and save it as `my_application.py`, then you should provide that name to machida as `--application-module my_application`.

## Resilience

If resilience is turned on, you can optionally specify the target directory for resilience files via the `--resilience-dir/-r` parameter (default is `/tmp`), and whether or not log should be rotated (`--log-rotation`, off by default). If log rotation is enabled, you may also set the file size on which to trigger log rotation (per worker, in bytes). If no file size is set, log rotation will only happen if it is requested via an external control channel message sent to the address specified in the cluster intializer worker's `--external` parameter. If a file size _is_ set, log rotation may trigger if either the log file reaches the specified file size, or if a log rotation is requested for the worker via the external control channel.

## Performance Flags

You can specify how many threads a Wallaroo process will use via the following
argument:

```bash
--ponythreads=4
```

If you do not specify the number of `ponythreads`, the process will try to use all available cores.

Since Machida (used for the Python API) is single-threaded, you must run it with `--ponythreads 1` or Machida will exit early.

There are additional performance flags`--ponypinasio` and `--ponynoblock` that can be used as part of a high-performance configuration. Documentation on how to configure for best performance is coming soon.
