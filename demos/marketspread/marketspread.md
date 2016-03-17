# Market Spread Demo

## Description

The market spread application takes two inputs (NBBO and Trades data) in 
FIX 4.2 format, and depending on the type, it may update some local state 
(NBBO, Trade) or emit an Accept/Reject message (Trades).

## Specification

The main reference for the application specification can be found at
https://docs.google.com/document/d/1qpxeWcWeUzymX6hOSWG_yuTunNd6J2UoyWLzTOQiiz4/edit

Below is a description of the specification as it is coded in the application.
In both cases, a message references only a single trading symbol.

### NBBO Input

For each message,
we determine for that symbol whether new trades should be accepted or
rejected. We do this by computing `Mid = (Offer + Bid) / 2` and
`StopNewOrders = (Offer – Bid) / Mid >= 5% AND (Offer-Bid) >= 5 Cents`
and if `StopNewOrders` evaluates to True, we stop accepting new orders for the
symbol until `StopNewOrders` becomes False.

In a worker's local state, we maintaing the following information per symbol:
- Symbol
- Transaction Time
- Bid
- Offer
- Mid
- StopNewOrders


### Trades Input

For each message:
- if no market data exists for the symbol, reject the order
- if market data exists and `StopNewTrades` is True, reject the order
- if market data exists and `StopNewTrades` is False, accept the order

## Running the demo - Simple toplogy

To run the demo, you need an input queue, and output queue, a worker, 
the demo data (`nbbo.msg` and `trades.msg` in this directory) and a data
feeder.
From the `Buffy/buffy` directory, execute the following commands in their own
shells:

1. `python3 UDP_listener.py --address 127.0.0.1:5000`
1. `python3 metrics_receiver.py --address 127.0.0.1:5001`
1. `python3 metrics_receiver.py --address 127.0.0.1:5002`
1. `python3 MQ_udp.py --address 127.0.0.1:10000 --console-log --metrics-addres 127.0.0.1:5001`
1. `python3 worker.py --input-address 127.0.0.1:10000 --output-address 127.0.0.1:5000 --output-type socket --console-log --function marketspread --metrics-address 127.0.0.1:5002`
1. `python3 feeder.py --address 127.0.0.1:10000 --console-log --path ../demos/trades.msg --path ../demos/nbbo.msg`

Note that we're using a separate receiver for MQ metrics and Worker metrics.
This isn't strictly necessary, and is mostly done for convenience when reading outputs.

## Reunning the demo - Complex topology (Tree routing)

The MQ nodes can handle about 12000 msgs/sec from the file feeder, but the 
workers can only handle about 4000 msgs/sec on the same machine. Normally,
we would just start up another worker and have them run in parallel,
consuming data from the same queue and pushing outputs to the same sink,
but in the market spread application, the local state of the worker affects
whether an order may be accepted or rejected, and so we must ensure that
all messages for the same symbol end up in the same worker.
One way to do this is to add a Router between the workers and the input queue:

    feeder -> MQ1 -> router -> MQ2 -> worker -> sink
                            -> MQ3 -> worker -> sink

We can do this with the following execution (each command in its own terminal):

1. `python3 UDP_listener.py --address 127.0.0.1:5000`
1. `python3 metrics_receiver.py --address 127.0.0.1:5001`
1. `python3 metrics_receiver.py --address 127.0.0.1:5002`
1. `python3 MQ_udp.py --address 127.0.0.1:10000 --stats-period 10 --metrics-address 127.0.0.1:5001 --vuid mq1`
1. `python3 MQ_udp.py --address 127.0.0.1:10001 --stats-period 10 --metrics-address 127.0.0.1:5001 --vuid mq2`
1. `python3 MQ_udp.py --address 127.0.0.1:10002 --stats-period 10 --metrics-address 127.0.0.1:5001 --vuid mq3`
1. `python3 worker.py --input-address 127.0.0.1:10000 --output-address 127.0.0.1:10001 --output-address 127.0.0.1:10002 --output-type queue --stats-period 10 --function fixrouter --metrics-address 127.0.0.1:5002 --vuid router1`
1. `python3 worker.py --input-address 127.0.0.1:10000 --output-address 127.0.0.1:10001 --output-address 127.0.0.1:10002 --output-type queue --stats-period 10 --function fixrouter --metrics-address 127.0.0.1:5002 --vuid router2`
1. `python3 worker.py --input-address 127.0.0.1:10002 --output-dress 127.0.0.1:5000 --output-type socket --stats-period 10 --function marketspread --metrics-address 127.0.0.1:5002 --vuid market1` 
1. `python3 worker.py --input-address 127.0.0.1:10002 --output-dress 127.0.0.1:5000 --output-type socket --stats-period 10 --function marketspread --metrics-address 127.0.0.1:5002 --vuid market2` 
