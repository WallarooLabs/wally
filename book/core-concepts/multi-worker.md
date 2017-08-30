# Multi-Worker apps

Wallaroo allows an application to be run on multiple workers. The topology is
automatically arranged between workers at startup, such that no additional work
is required on the developer's part.


## Decentralized synchronization

A Wallaroo cluster does not have a continuously-running centralized manager for
its workers, so coordination is all done on a decentralized basis.


### The Initializer

At cluster startup, one worker assumes the role of "initializer". This means
that this worker is responsible for coordinating the startup of all other
workers. A worker is deemed to be an initializer by passing the
`--topology-initializer` command line argument.


### Multiple workers

To create a topology with multiple workers, each worker needs to be started with
the `--worker-count` option, and well as a `--worker-name` option, the latter
being unique for each worker. Each worker will have to know the host and
port for the control channel, via the `--control-channel` options. This is used
to communicate with the initializer: the worker designated as initializer
will be listening on that address, and all other workers will be connecting to
it at startup to coordinate the topology distribution and synchronization.


### Restarting workers

All the workers in a newly-started cluster, will save topology information
locally in the resilience directory (`/tmp/` if none is provided via the
`--resilience-dir` command line option). At every worker's subsequent startup,
it will check for these files, and if present, it will attempt to reconnect to
the existing cluster specified in the resilience files.


### Shutting down a cluster

To entirely shut down a cluster, simply terminate all the running workers.
If you intend to start a new cluster, you will have to delete the files created
in the resilience directory.


## Compatibility

Currently, any Wallaroo app can be run with multiple workers. However, certain
design considerations have to be made.


### Coalescing

Certain types of computations will be "coalesced": this means that, under
certain circumstances and rules, they will be joined to their preceding or following
computations, and treated as a single computation.


### Simple computation

A simple computation will live on a single worker. If you have multiple simple
computations in a row, these are coalesced on a single worker and cannot be
separated.


### Stateful computations

Like simple computations, a single stateful computation can only live on a
single worker. A stateful computation interrupts the chain of coalescing of all
the preceding simple computations and remains separated from them, so that any
subsequent and preceding computation chains can be separated and if deemed necessary can be
allocated to different workers.


### Partitioned computations

Partitioned computations are distributed uniformly across workers. This means
that worker `A` may be responsible for a certain set of keys, while worker `B`
will be responsible for others. Each key is processed only by one worker,
without overlaps.


## Example

This section illustrates how to run the
[Alphabet example](../examples/pony/alphabet/README.md)
with two workers. This example assumes that all workers are running on the same
host. If not, you must replace IP addresses accordingly.

0. Build the application and generate the data in the same way as the
single worker version of the instructions.

1. Start the metrics UI and the listener as indicated as well.

2. Start the initializer:

We use the `--topology-initializer` argument to signal that this process is in
charge of initializing the cluster topology. We tell it to expect a total of 2
workers (including itself), and give it a name of 'worker1'.

```bash
./alphabet --in 127.0.0.1:7010 --out 127.0.0.1:7002 --metrics 127.0.0.1:5001 \
  --control 127.0.0.1:12500 --data 127.0.0.1:12501 --topology-initializer
  --worker-count 2 --worker-name worker1
```

3. Start a second worker:

Note how we have changed the name of the worker and the input port, to avoid
conflicts with the initializer.
```bash
./alphabet --in 127.0.0.1:7011 --out 127.0.0.1:7002 --metrics 127.0.0.1:5001 \
  --control 127.0.0.1:12500 --data 127.0.0.1:12501 --worker-count 2
  --worker-name worker2
```

4. Start the sender as indicated in the single worker instructions.
