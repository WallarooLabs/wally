#!/usr/bin/env python3

import subprocess
import os

DEVNULL = open(os.devnull, 'w') # For suppressing stdout/stderr of subprocesses
SINK_ADDRESS = '127.0.0.1:7003'
METRICS_ADDRESS = '127.0.0.1:7004'
MQ_ADDRESS = '127.0.0.1:9002'
STATS_PERIOD = '1'
FUNCTION = 'marketspread'
URI = 'http://127.0.0.1:4000/api/v1/metrics'
NBBO = '../demos/marketspread/nbbo.msg'
TRADES = '../demos/marketspread/trades.msg'
DELAY = '0.001'

subprocess.Popen(["python3", "metrics_receiver.py", "--address", METRICS_ADDRESS,
                 "--uri", URI], stdout=DEVNULL, stderr=DEVNULL)
subprocess.Popen(["python3", 'sink.py', '--address', SINK_ADDRESS,
                 '--metrics-address', METRICS_ADDRESS, '--stats-period',
                 STATS_PERIOD, '--vuid', 'MARKET_SPREAD'], stdout=DEVNULL, stderr=DEVNULL)
subprocess.Popen(["python3", 'MQ_udp.py', '--address', MQ_ADDRESS, '--metrics-address',
                 METRICS_ADDRESS, '--stats-period', STATS_PERIOD, '--vuid', 'NODE_1'],
                 stdout=DEVNULL, stderr=DEVNULL)
subprocess.Popen(["python3", 'worker.py', '--input-address', MQ_ADDRESS,
                 '--output-address', SINK_ADDRESS, '--output-type', 'socket',
                 '--metrics-address', METRICS_ADDRESS, '--stats-period',
                 STATS_PERIOD, '--function', FUNCTION, '--vuid', 'NODE_2'],
                 stdout=DEVNULL, stderr=DEVNULL)
subprocess.Popen(["python3", 'feeder.py', '--address', MQ_ADDRESS, '--path', NBBO,
                 '--path', TRADES, '--delay', DELAY], stdout=DEVNULL, stderr=DEVNULL)

