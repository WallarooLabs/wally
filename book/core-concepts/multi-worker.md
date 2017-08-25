# Multi-Worker apps

Wallaroo allows an application to be run on multiple workers. The topology is
automatically arranged between workers at startup, such that no additional work
is required on the developer's part.

## Decentralised synchronisation

A Wallaroo cluster does not have a continuously-running centralised manager for
its workers, so coordination is all done on a decentralised basis.

### Multiple workers
To create a topology with multiple workers, each worker needs to be started with
the `--worker-count` option, and well as a `--worker-name` option, which is
unique for each worker. Also, each worker will have to know the host and port
for the control channel, via the `--control-channel` options. This is used to
communicate with the initializer, so the worker designated as initializer will
be listening on that address, and the other workers will be connecting to it for
synchronisation.

### The Initializer
At cluster startup, one worker assumes the role of "initializer". This means
that this worker is responsible for coordinating the startup of all other
workers. A worker is deemed to be an initializer by passing the
`--topology-initializer` command line argument.

### Restarting workers
At startup, all the workers synchronise to generate a "cluster ID". This is so
that if a worker fails and has to be restarted, this cluster ID can be used to
identify and reload the correct topology. If a worker is restarted without the
`--cluster-id` option, it will always try to join a new cluster.

### Shutting down a cluster
To entirely shut down a cluster, simply terminate all the running workers.

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

### Partitioned compuations
Partitioned computations are distributed uniformly across workers. This means
that worker `A` may be responsible for a certain set of keys, while worker `B`
will be responsible for others. Each key is processed only by one worker,
without overlaps.
