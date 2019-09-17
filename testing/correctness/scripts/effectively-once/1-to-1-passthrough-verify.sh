#!/bin/sh

# This script makes *many* assumptions:
#
# 1. We're using a "passthrough" Wallaroo app
#
# 2. The input file is ASCII and is newline-delimited, and the ALOC
#    source sends data in 1 line per message, and thus the ALOC sink
#    writes these 1-line messages as-is and then commits via 2PC
#    groups of 0 or more entire & intact lines.
#
# 3. The input file has all lines beginning with the same character,
#    e.g., ASCII "T".
#
# 4. For small Wallaroo clusters, the lines beginning with the
#    character "T" will always be routed to worker2.
#
# 5. We follow the TCP port and file input/output naming conventions
#    of the scripts in this directory.
#
# 6. We start the ALOC sink like this:
#    mkdir -p /tmp/sink-output
#    env PYTHONPATH=~/wallaroo/machida/lib ~/wallaroo/testing/correctness/tests/aloc_sink/aloc_sink /tmp/sink-out/output /tmp/sink-out/abort 7200 > /tmp/sink-out/stdout-stderr 2>&1
#
# 7. We can use brute force shell script fu to find the end offset of
#    the last committed transaction (or assume that the committed
#    offset is 0) without resorting to parsing the aloc_sink's
#    output.worker2.txnlog file with Python to be accurate.
#
# 8. Tools like "dd" and "cmp" are sufficient to verify that the
#    output that the aloc_sink gets is correct.
#
# 9. This script will be for 1-time verification use.

INPUT=$1
OUTPUT_DIR=/tmp/sink-out
OUTPUT=`ls -l /tmp/sink-out/output.* | grep -v txnlog | sort -nr -k 5 | head -1 | awk '{ print $9 }'`
OUTPUT_TXNLOG=$OUTPUT.txnlog
TMP_INPUT=`mktemp /tmp/first-bytes-of-input.XXXXX`
TMP_OUTPUT=`mktemp /tmp/first-bytes-of-output.XXXXX`
rm -f $TMP_INPUT $TMP_OUTPUT
trap "rm -f $TMP_INPUT $TMP_OUTPUT" 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15

if [ ! -f $INPUT ]; then
    echo Error: usage: $0 /path/to/input-file
    echo "File '$INPUT' does not exist"
    exit 1
fi
if [ ! -f $OUTPUT -o ! -f $OUTPUT_TXNLOG ]; then
    echo Error: calculated file $OUTPUT and/or $OUTPUT_TXNLOG does not exist
    exit 1
fi

sink_offset=0
tmp=`grep "2-ok" $OUTPUT_TXNLOG | tail -1 | \
     sed -e 's/.*, //' -e 's/\].*//'`
if [ ! -z "$tmp" ]; then
    sink_offset=$tmp
fi

cmp -n $sink_offset $INPUT $OUTPUT
if [ $? -eq 0 ]; then
    exit 0
else
    dd if=$INPUT bs=$sink_offset count=1 > $TMP_INPUT 2> /dev/null
    dd if=$OUTPUT bs=$sink_offset count=1 > $TMP_OUTPUT 2> /dev/null
    ls -l $TMP_INPUT $TMP_OUTPUT
    diff -u $TMP_INPUT $TMP_OUTPUT
    echo ERROR
    exit 1
fi
