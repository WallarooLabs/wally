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
# 3. The input file SHOULD have all lines beginning with the same character,
#    e.g., ASCII "A".  That same character is given to us on the
#    command line as argument $1.  We use KEY=$1 to filter lines
#    that begin with that letter because the 1st char in the line is
#    Wallaroo's routing key, and Wallaroo has limits order guarantees
#    only on single routing keys.
#    If the file contains more than one routing key, then this script
#    should be run multiple times: once for each unique routing key.
#
# 5. We follow the TCP port and file input/output naming conventions
#    of the scripts in this directory.
#
# 6. We start the ALOC sink like this:
#    mkdir -p /tmp/sink-output
#    env PYTHONPATH=$WALLAROO_TOP/machida/lib $WALLAROO_TOP/testing/correctness/tests/aloc_sink/aloc_sink /tmp/sink-out/output /tmp/sink-out/abort 7200 > /tmp/sink-out/stdout-stderr 2>&1
#
# 7. We rely on the small Python script `concat-sink-output.py` to
#    concatenate chunks of data from various sink files, in the order
#    that they were written by Wallaroo, into a single ordered file.
#
# 8. Tools like "dd" and "cmp" are sufficient to verify that the
#    output that the aloc_sink gets is correct.
#
# 9. This script will be for point-in-time verification use.

KEY=$1
INPUT=$2
MULTI_KEY_TMP_FILE=$3
OUTPUT_DIR=/tmp/sink-out
OUTPUT=$OUTPUT_DIR/output.concatenated

TMP_INPUT=`mktemp /tmp/first-bytes-of-input.XXXXX`
TMP_OUTPUT=`mktemp /tmp/first-bytes-of-output.XXXXX`
rm -f $TMP_INPUT $TMP_OUTPUT
trap "rm -f $TMP_INPUT $TMP_OUTPUT" 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15

if [ ! -f $INPUT ]; then
    echo Error: usage: $0 /path/to/input-file
    echo "File '$INPUT' does not exist"
    exit 1
fi

if [ -z "$MULTI_KEY_TMP_FILE" ]; then
    (./concat-sink-output.py $OUTPUT_DIR/*.txnlog | \
        egrep "^$KEY") 1> $OUTPUT 2> $OUTPUT.mapping
else
    if [ ! -f $MULTI_KEY_TMP_FILE ]; then
        ##/bin/echo -n CONCAT > /dev/tty
        ./concat-sink-output.py $OUTPUT_DIR/*.txnlog \
            1> $MULTI_KEY_TMP_FILE 2> $MULTI_KEY_TMP_FILE.mapping
    fi
    egrep "^$KEY" < $MULTI_KEY_TMP_FILE > $OUTPUT 2> $OUTPUT.mapping
fi
output_size=`ls -l $OUTPUT | awk '{print $5}'`
##/bin/echo -n v$KEY,$output_size, > /dev/tty

cmp -n $output_size $INPUT $OUTPUT
if [ $? -eq 0 ]; then
    exit 0
else
    dd if=$INPUT bs=$output_size count=1 > $TMP_INPUT 2> /dev/null
    dd if=$OUTPUT bs=$output_size count=1 > $TMP_OUTPUT 2> /dev/null
    ls -l $TMP_INPUT $TMP_OUTPUT
    diff -u $TMP_INPUT $TMP_OUTPUT
    echo ERROR
    exit 1
fi
