#!/bin/bash

SINK_ADDRESS=127.0.0.1:5000
METRICS_ADDRESS=127.0.0.1:5001
MQ_ADDRESS=127.0.0.1:10000
STATS_PERIOD=1
FUNCTION=marketspread
URI=http://127.0.0.1:4000/api/v1/metrics
NBBO=../demos/marketspread/nbbo.msg
TRADES=../demos/marketspread/trades.msg
DELAY=0.001

python3 metrics_receiver.py --address $METRICS_ADDRESS --uri $URI
python3 sink.py --address $SINK_ADDRESS --metrics-address $METRICS_ADDRESS --stats-period $STATS_PERIOD --vuid MARKET_SPREAD
python3 MQ.py --address $MQ_ADDRESS --metrics-address $METRICS_ADDRESS --stats-period $STATS_PERIOD --vuid NODE_1
python3 worker.py --input-address $MQ_ADDRESS --output-address $SINK_ADDRESS --output-type socket --metrics-address $METRICS_ADDRESS --stats-period $STATS_PERIOD --function $FUNCTION --vuid NODE_2
python3 feeder.py --address $MQ_ADDRESS --path $NBBO --path $TRADES --delay $DELAY
