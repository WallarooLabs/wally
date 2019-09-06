#!/bin/sh

if [ `uname -s` != Linux ]; then
    ## We're using GNU's getopt not BSD's {sigh}
    echo Error: Not a Linux system
    exit 1
fi

echo TODO

exit 0
