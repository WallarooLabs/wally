# Prototype/Scratch implementation of a set of barebones stream processing building blocks

The goal of this repo is to provide reference functionality for a barebones set of building blocks
with which to build stream processing topologies with tunable guarantees.


## Requirements:

1. Python 3.4 or higher
2. click
3. requests


## Running the stream-py prototype


### Starting a Message Queue Node

    python3 MQ_udp.py --address <host>:<port>>

### Starting a Worker (pong) Node

    python3 worker.py --input-address <host>:port --output-address <host>:<port> --output-type queue --console-log --function=pong


### Seeding the first 'ping' message to start the game

    python3 udp-client.py <mq_host>:<mq_port> PUT:pong


## The Message Queue Node:

The message queue node supports the following commands (sent via UDP):

    PUT:<message>
    GET
    SIZE

## Forward Streaming Protocol
All components of this prototype (`MQ_udp.py`, `udp-client.py`, `worker.py`) use a forward-parsing
encoding protocol where each message has the following structure:

    LHHTTT

where 

 - `TTT` is the message text
 - `HH` is the message text's length, as a hexadecimal string
 - `L` is the the hexadecimal string's length, in a single hexadecimal character

For example, the message `Hello World` will be encoded as `1bHello World`, and the message `abcdefghijklmnopqrstuvwxyz` will
be encoded as `21aabcdefghijklmnopqrstuvwxyz`.

This format allows a maximum message size of 2^60 bytes, or a little over 1.1 exabyte. This is probably sufficient for our needs.


## Playing Pong
Pong is a simple game: when you receive a `ping` message, you respond with a `pong`,
and when you receive a `pong` message, you respond with a `ping`.
For the purposes of illustrating connectivity on a graph, the game can also be expanded
such that a node may listen to multiple inputs, and send its response to any of its
connected outputs either deterministically or with random sampling.

In its simplest form, the game requires only one edge (a message queue) and one node (a worker).
We can set up the graph manually by running the following commands in two separate shells:

    python3 MQ_udp.py --address=127.0.0.1:10000 --console-log
    python3 worker.py --input-address=127.0.0.1:10000 --output-address=127.0.0.1:10000 --output-type=queue --console-log --function=pong 

This creates a graph with one node connected to itself via one edge:

    worker------+
    ^           |
    +----MQ-----+

We begin the game by using an external client to add either a 'ping' or a 'pong' message to the 
message queue:

    python3 udp-client.py 127.0.0.1:10000 PUT:ping

Note that if `--file-log` is used, this will generate logs per node in the `logs` directory, and these will grow rapidly. 

## Multiple Outputs (A Tree Topology)
The workers are capable of making a choice about which output a message should be sent to.
This requires two things:

    1. That mutliple output address be provided using the `--output-address` parameter
    2. That the function specified in `--function` return a tuple of the form `(choice, message)`. 

`choice` is then used, modulo the length of the outputs list, to select an output target.
e.g. if `func(input)` returns `(10, 'hello world')`, and we have the output list `outputs = [out1, out2, out3]`, then `out2` will be used (`10 % 3 == 1`, and `outputs[1] == out2`).

## Metrics Reports
The monitoring hub expects the following pipeline keys:
- MARKET_SPREAD (metrics for total pipeline values)
- NODE_1 (metrics for MQ)
- NODE_2 (metrics for marketspread worker)

It also expects to receive a message for each of these once per second.

`metrics_receiver.py`, on the other hand, processes whatever it receives and sends it to the monitoring hub uri given to it in the `--uri` parameter. This means that in order for metrics to be sent to the monitoring hub once per second, they need to be emitted once per second _by the metrics collectors_, or the MQ, the worker, and the sink, in this case.
To do this, they need to be started with the following parameters:

```sh
SINK_ADDRESS = 127.0.0.1:5000
METRICS_ADDRESS = 127.0.0.1:5001
MQ_ADDRESS = 127.0.0.1:10000
STATS_PERIOD = 1
FUNCTION = marketspread
URI = http://127.0.0.1:5555/post
NBBO = ../demos/marketspread/nbbo.msg
TRADES = ../demos/marketspread/trades.msg
DELAY = 0.001

python3 metrics_receiver.py --address $METRICS_ADDRESS --uri $URI
python3 sink.py --address $SINK_ADDRESS --metrics-address $METRICS_ADDRESS --stats-period $STATS_PERIOD --vuid MARKET_SPREAD
python3 MQ.py --address $MQ_ADDRESS --metrics-address $METRICS_ADDRESS --stats-period $STATS_PERIOD --vuid NODE_1
python3 worker.py --input-address $MQ_ADDRESS --output-address $SINK_ADDRESS --output-type socket --metrics-address $METRICS_ADDRESS --stats-period $STATS_PERIOD --function $FUNCTION --vuid NODE_2
python3 feeder.py --address $MQ_ADDRESS --path $NBBO --path $TRADES --delay $DELAY
```