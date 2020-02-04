#!/bin/sh

OUT=/tmp/run_aloc_sink_test.out
ITER="$1"
EXPECT="$2"
if [ -z "$ITER" -o -z "$EXPECT" ]; then
    echo "Usage: $0 iteration-number commit|abort"
    exit 1
fi

echo Iteration $ITER
rm -f /tmp/Celsius* /tmp/aloc* $OUT
./run_aloc_sink_test ./aloc_sink.abort-rules.$ITER > $OUT 2>&1

./run_aloc_sink_test.validate.sh $EXPECT
if [ $? -ne 0 ]; then
    echo FAILED $ITER
    cat /tmp/run_aloc_sink_test.out
    exit 1
fi

exit 0

