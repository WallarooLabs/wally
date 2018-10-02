# Testing Reconnect in Wallaroo

## Description

Wallaroo can run a single application topology across several hosts. In order to properly test this behaviour, it is important to understand how it is implemented.
Since Wallaroo topologies are DAGs, they are implemented as a collection of steps strung together by a lookup map. At the end of each step, a router is used to determine where the next step in the DAG resides. If it is local, the step is executed with the output of the current step. If, however, the next step is on another host, we have to move the output of the current step over to the correct step on the correct host. This flow looks like:

```
[HOST_A: step -> router -> proxy router (if on another host) -> specific boundary] -> data_channel ->
[HOST_B: data_receiver  -> data_router -> step]
```


##  Testing Boundary Reconnection
Before we can test the reconnection behaviour, we must first introduce a disconnect in the system.
To do this, we can use `spike`, a compile-time fault injection component of Wallaroo.
`Spike` takes two parameters in the standard application startup: `--spike-drop`, a boolean determining whether the current process should perform any fault injection on its boundary connections, and `--spike-seed`, a value which is used to seed `Spike`'s psuedo-random choice of when to drop a connection. If you use the same seed value, you will get the exact same choices, in the same sequence, which is very useful to testing.

In addition to `Spike`, we also need a boundary in our application.
Luckily, `sequence_window` already has a boundary when run with two workers, so that's taken care of.

The gist of the test is simple: We run `sequence_window` with `Spike` on the `initializer` worker, and observe that once the connection is dropped, a reconnect behaviour follows, is successful, and the data resumes to both processes of the application.


### Setting Up for the Test:

1. build Data Receiver and Giles Sender
2. build `testing/correctness/apps/sequence_window` with `-D spike` (and optionally `-d` for debug messages)

### Running the Test:

1. start data receiver:  `../../../../utils/data_receiver/data_receiver --framed --ponythreads=1 --ponynoblock --ponypinasio -l 127.0.0.1:5555 > received.txt`
2. start initializer-worker: `./sequence_window -i 127.0.0.1:7000 -o 127.0.0.1:5555 -m 127.0.0.1:5001 --ponythreads=4 --ponypinasio --ponynoblock -c 127.0.0.1:12500 -d 127.0.0.1:12501 -r res-data -w 2 -n worker1 -t --spike-drop --spike-prob 0.001 --spike-margin 1000`
3. start second worker: `./sequence_window -i 127.0.0.1:7000 -o 127.0.0.1:5555 -m 127.0.0.1:5001 --ponythreads=4 --ponypinasio --ponynoblock -c 127.0.0.1:12500 -r res-data -n worker2`
4. start giles-sender and send 10000 integers: `../../../../giles/sender/sender -h 127.0.0.1:7000 -s 10 -i 5_000_000 -u --ponythreads=1 -y -g 12 -w -m 10000`
5. wait for giles-sender to complete
6. Terminate all of the processes

### Analysing the Test Results:

#### Automatically
1. Compile `testing/correctness/apps/sequence_window/validator`
2. run `validator/validator -i received.txt -e 1000`

#### Manually

1. Decode the giles-receiver output with fallor and visually inspect the output sequences to comply with the expectation described above.
