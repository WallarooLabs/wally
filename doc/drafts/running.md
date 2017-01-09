# Running a Wallaroo App

## Building

Let's say we'd like to run the [celsius conversion app](...). We need to
first build our binary (see [Setting Up Pony](...) for background information). 

Say our code is in a file called `celsius.pony` in
the directory `~/dev/celsius/`. Navigate to the app folder and run

```
stable fetch && stable env ponyc
```

to build the binary. Pony binaries take the name of the directory they are
built in, so in this case we build a binary called `celsius`.

## Command Line Parameters

When running a Wallaroo app binary, we use some of the following command line
parameters (a star indicates it is required, a plus that it is required for multi-worker runs):

```
      --in/-i *[Comma-separated list of input addresses sources listen on]
      --out/-o *[Sets address for sink outputs]
      --control/-c +[Sets address for control channel]
      --data/-d +[Sets address for data channel]
      --worker-count/-w +[Sets total number of workers, including topology
        initializer]
      --worker-name/-n +[Sets name for this worker]
      --metrics/-m [Sets address for external metrics (e.g. monitoring hub)]
      --topology-initializer/-t [Flag that sets this process as the 
        initializer]
      --resilience-dir/-r [Sets directory to write resilience files to,
        e.g. -r /tmp/data (no trailing slash)]
```

Wallaroo currently supports one input stream per pipeline. We provide 
comma-separated IP addresses for TCP source listeners via the `--in` parameter. Currently, the order of these addresses corresponds to the order in which pipelines are defined in your app code. 

Wallaroo currently supports one sink per app. Use the `--out` parameter to 
specify the address that this sink will write out to over TCP.

In order to monitor metrics, we must specify the target address for metrics data via the `--metrics` parameter.

TODO: The following parameters should not be required on single worker runs: -c, -d

### Multi-Worker Setup

A Wallaroo topology can be distributed over multiple Wallaroo processes, or "workers". When a Wallaroo application first spins up, one of these workers 
plays the role of the "initializer", a temporary role that only has significance during initialization (after that, the cluster is decentralized).

We specify that a worker will play the role of initializer via the 
`--topology-initializer` flag. We specify the total number of workers at startup (including the initializer) via the `--worker-count` parameter.

Workers communicate with each other over two channels, a control channel and a data channel. We need to tell every worker which addresses the initializer is listening on for each of these channels. `--control` specifies the 
initializer's control address and `--data` specifies the initializer's data address.

Remember that multi-worker runs require that you distribute the same binary to all machines that are involved. Pony serialization does not currently work between different Pony binaries.

### Resilience

If resilience is turned on, you can optionally specify the target directory for
resilience files via the `--resilience-dir` parameter (default is `/tmp`).



 



