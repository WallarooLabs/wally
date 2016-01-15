#!/bin/bash

# Start message queues
./MQ_udp.py 127.0.0.1:10000 &


# Wait 0.5 second before starting workers to ensure MQs are available
sleep 0.5

# start workers
./worker.py 127.0.0.1:10000 127.0.0.1:10000 

# Kill backgrounded processes when the main script exits
trap 'kill $(jobs -pr)' SIGINT SIGTERM EXIT

