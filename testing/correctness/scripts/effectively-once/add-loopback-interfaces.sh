#!/bin/sh

if [ `uname -s` != Linux ]; then
    echo Error: Not a Linux system
    exit 1
fi

if [ -z "$MAX_ADDRESS" ]; then
    MAX_ADDRESS=32
fi

for i in `seq 2 $MAX_ADDRESS`; do
    sudo ifconfig lo add 127.0.0.$i netmask 255.0.0.0
done

exit 0
