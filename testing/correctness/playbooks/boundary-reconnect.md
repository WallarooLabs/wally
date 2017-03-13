# Testing Reconnect in Wallaroo

## Description

Wallaroo's can run a single application topology across several hosts. This is done by using two components: proxy routers, and boundary steps.
Between each pair of steps in a topological sequence, a proxyrouter is used to determine where the next step resides, in order for Wallaroo to be able to correct link up the steps in order. If the next stop in a topology resides on another host, then the output of the current step is sent to a _local_ boundary step, which forwards the message to the boundary receiver on the correct host, which in turn forwards the message to the correct step in the topology.


##  Testing Boundary Reconnection
Before we can test the reconection behaviour, we must first introduce a disconnect in the system.
To do this, we can use `spike`, a compile-time fault injection component of Wallaroo.
`Spike` takes two parameters in the standard application startup: `--spike-drop`, a boolean determining whether the current process should perform any fault injection on its boundary connections, and `--spike-seed`, a value which is used to seed `Spike`'s psuedo-random choice of when to drop a connection. If you use the same seed value, you will get the exact same choices, in the same sequence, which is very useful to testing.

In addition to `Spike`, we also need a boundary in our application.
Luckily, `sequence-window` already has a boundary when run with two workers, so that's taken care of.

The gist of the test is simple: We run `sequence-window` with `Spike` on the `initializer` worker (the sending side of the boundary), and observe that once the connection is dropped, a reconnect behaviour follows, is successfull, and the data resumes to both processes of the application.


### Setting Up for the Test:

1. build Giles receiver and sender
1. build `testing/correctness/apps/sequence-window` with `-D spike` (and optionally `-d` for debug messages)

### Running the Test:

1. start giles-receiver:  `../../../../giles/receiver/receiver --ponythreads=1 --ponynoblock --ponypinasio -l 127.0.0.1:5555`
1. start initializer-worker: `./sequence-window -i 127.0.0.1:7000 -o 127.0.0.1:5555 -m 127.0.0.1:5001 --ponythreads=4 --ponypinasio --ponynoblock -c 127.0.0.1:12500 -d 127.0.0.1:12501 -w 2 -n worker1 -t --spike-drop --spike-seed 1`
1. start second worker: `./sequence-window -i 127.0.0.1:7000 -o 127.0.0.1:5555 -m 127.0.0.1:5001 --ponythreads=4 --ponypinasio --ponynoblock -c 127.0.0.1:12500 -d 127.0.0.1:12501 -w 2 -n worker2`
1. start giles-sender and send the first 1000 integers, slowly: `../../../../giles/sender/sender -b 127.0.0.1:7000 -s 10 -i 100_000_000 -u --ponythreads=1 -y -g 12 -w -m 1000`
1. If you built the application in Debug mode, then each worker will have printed to its stdout the values in its sequence window at each step, and you can verify that the sequence at the second worker has reached `[994, 996, 998, 1000]` as we expect it to if it reconnects successfully.
1. Terminate all of the processes

### Analysing the Test Results:

#### Automatically
1. Compile `testing/correctness/apps/sequence-window/validator`
2. run `validator/validator -i received.txt -e 1000`

#### Manualy

1. Decode the giles-receiver output with fallor and visually inspect the output sequences to comply with the expectation described above.

