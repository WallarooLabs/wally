#!/bin/sh

killall -9 aloc_passthrough; killall python python3

rm -rf /tmp/sink-out
mkdir -p /tmp/sink-out
touch /tmp/sink-out/abort-rules

rm -f /tmp/Pass*
