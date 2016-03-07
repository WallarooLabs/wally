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

## Running the demo

To run the demo, you need an input queue, and output queue, a worker, 
the demo data (`nbbo.msg` and `trades.msg` in this directory) and a data
feeder.
From the `Buffy/buffy` directory, execute the following commands in their own
shells:
1. `python3 MQ_udp.py --address 127.0.0.1:10000 --console-log`
2. `python3 MQ_udp.py --address 127.0.0.1:10001 --console-log`
3. `python3 worker.py --input-address 127.0.0.1:10000 --output-address 127.0.0.1:10001 --output-type queue --console-log --function marketspread`
4. `python3 feeder.py --address 127.0.0.1:10000 --console-log --path ../demos/trades.msg --path ../demos/nbbo.msg`
