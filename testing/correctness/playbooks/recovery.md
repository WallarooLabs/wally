# Testing Recovery in Wallaroo

## Description

Wallaroo's resilience is effected by saving the state-change diffs of stateful actors to a log file, as well as replay-capabilities in upstream actors.
When a wallaroo worker starts, it checks to see if a resilience log file exists under its name, and if it does, then it attempts to recover its state from the file, by replaying all of the state diffs on each actor.

##  Testing State Recovery
In order to test whether a state's recovery is successful, we need the ability to observe the state before and after a recovery.
This is done via a simple app, that keeps track of a fixed window of history of the integer values it receives. On each message received, the oldest value in the window is ejected and the newest is inserted.
A successful recovery would yield the same sequence of outputs as a run with the same input but which does not undergo a failure-recovery cycle.
e.g. if in the control run, we observed the sequence of outputs `[10,11,12,13], [11,12,13,14]`, and if failure-recovery happened between the messages `13` and `14` of the test run, then the sequence of outputs `[10,11,12,13], [11,12,13,14]` would indicate a successful recovery. If state was not successfully recovered, we might see the sequence `[10,11,12,13], [0,0,0,14]` instead, for example.

### Setting Up for the Test:

1. build Data Receiver and Giles Sender
1. build `testing/correctness/apps/sequence_window` with `-D resilience` (and optionally `-d` for debug messages)
1. create a `res-data` directory in the `testing/correctness/apps/sequence_window` directory

### Running the Test:

1. start data receiver:  `../../../../utils/data_receiver/data_receiver --framed --ponythreads=1 --ponynoblock --ponypinasio -l 127.0.0.1:5555 > received.txt`
1. start initializer-worker: `./sequence_window -i 127.0.0.1:7000 -o 127.0.0.1:5555 -m 127.0.0.1:5001 --ponythreads=4 --ponypinasio --ponynoblock -c 127.0.0.1:12500 -d 127.0.0.1:12501 -r res-data -w 2 -n worker1 -t`
1. start second worker: `./sequence_window -i 127.0.0.1:7000 -o 127.0.0.1:5555 -m 127.0.0.1:5001 --ponythreads=4 --ponypinasio --ponynoblock -c 127.0.0.1:12500 -r res-data -n worker2`
1. start giles-sender and send the first 10000 integers: `../../../../giles/sender/sender -h 127.0.0.1:7000 -s 100 -i 50_000_000 -u --ponythreads=1 -y -g 12 -w -m 10000`
1. terminate the second worker with Ctrl-C
1. restart the second worker with the same command
1. use giles sender to send the next 2 integers in the sequence: (10001,10002): `../../../../giles/sender/sender -h 127.0.0.1:7000 -s 100 -i 50_000_000 -u --ponythreads=1 -y -g 12 -w -m 2 -v 10000`
1. If you built the application in Debug mode, then each worker will have printed to its stdout the values in its sequence window at each step, and you can verify that the sequence "remembered" by the second worker after recovery is `[9996, 9998, 10000, 10002]` as expected.
1. Terminate all of the processes

### Analysing the Test Results:

#### Automatically
1. Compile `testing/correctness/apps/sequence_window/validator`
2. run `validator/validator -i received.txt -e 10002`

#### Manualy

1. Decode the giles-receiver output with fallor and visually inspect the output sequences to comply with the expectation described above.

## Testing Mute and Replay from Upstream Boundaries
This test is similar to testing state recovery, except we run giles sender with a batch size of 1 and with larger intervals.

### Running the Test:

1. start data receiver, worker 1, and worker 2 as in the previous test
1. run giles with: `../../../../giles/sender/sender -h 127.0.0.1:7000 -s 1 -i 2_000_000_000 -u --ponythreads=1 -y -g 12 -w -m 10000`
1. wait for a few lines to go through
1. terminate worker2
1. wait some more
1. restart worker2

### Analysing the Test Results:

1. look at the output and ensure worker 2's windows follow correctly (`[0, 2, 4, 8], [2, 4, 8, 10], ...`) without gaps.

## Testing Recovery in Market-Spread / Arizona
While it's great that we can observe a successful recovery in a specially designed application, we also want to test it in our "real" applications, such as market-spread (pony) or arizona (c++).
To do this we use more or less the same technique as above: the A/B test.
We do two separate runs with the exact same input:
The first run is executed to completeness without failure, and then sent a set of query messages to produce outputs that depend on the state kept in the application.
In the second run, we terminate and restart a non-initializer worker during the run. After all of the input data is processed, we send in the same set of query messages as we did in the previous run. We then compare both outputs and test our hypothesis, that both outputs should be the same (after resorting by message id, to account for ordering variation between the two runs).

### Setting Up for the Test:
TODO: fill this up

### Running the Test:
TODO: fill this up

### Analysing the Test Results:
TODO: fill this up
