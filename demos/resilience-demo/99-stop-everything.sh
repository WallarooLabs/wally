#!/bin/sh

. ./COMMON.sh

SERVERS="$SERVER1_EXT $SERVER2_EXT $SERVER3_EXT $SERVER4_EXT"
echo Stopping all Wallaroo procs on $SERVERS
for i in $SERVERS; do
    ssh -n $USER@$i "killall -9 $WALLAROO_NAME sender receiver data_receiver beam.smp python python3 Python > /dev/null 2>&1 ; mkdir -p /tmp/run-dir" &
done
wait
