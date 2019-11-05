#!/bin/sh

echo WARNING: all useful state files are deleted by this script!

killall -9 passthrough > /dev/null 2>&1
killall python python3 > /dev/null 2>&1
killall Python Python3 > /dev/null 2>&1

rm -rf /tmp/sink-out/*
mkdir -p /tmp/sink-out

rm -f /tmp/Pass*
rm -f /tmp/wallaroo.*
