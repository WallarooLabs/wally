#!/bin/sh

VALIDATION_TOTAL=2000
VALIDATION_MIDWAY=1000

export START_RECEIVER_CMD='env PYTHONPATH="./testing/tools/integration" \
  python ./utils/resilience-demo/validation-receiver.py ${SERVER1}:5555 \
  '$VALIDATION_TOTAL' 11 600 ./received.txt'

export WALLAROO_BIN="./testing/correctness/apps/multi_partition_detector/multi_partition_detector"

export START_SENDER_CMD2='env PYTHONPATH="./testing/tools/integration" \
  python ./utils/resilience-demo/validation-sender.py ${SERVER1}:7000 \
  '$VALIDATION_MIDWAY' '$VALIDATION_TOTAL' 100 0.05 11'

. ./COMMON.sh

echo To stop everything, run: env WALLAROO_BIN="./testing/correctness/apps/multi_partition_detector/multi_partition_detector" ./99-stop-everything.sh

./20-start-2worker-cluster.sh
if [ $? -ne 0 ]; then
    echo STOP with non-zero status
fi

. ./SEND-1k.sh
echo Sleep 4 before restarting worker2; sleep 4

echo Kill worker2
./40-kill-worker.sh 2

## What we'd do to restart worker2 on server 2 with same TCP ports
echo Restart worker2 on server 2 with same TCP ports
ssh -n $USER@$SERVER2_EXT "mkdir -p /tmp/run-dir/OLD ; mv -v /tmp/run-dir/m* /tmp/run-dir/OLD"
./62-restart-worker-no-port-change.sh 2 2
if [ $? -ne 0 ]; then
    exit 1
fi

env START_SENDER_CMD="$START_SENDER_CMD2" START_SENDER_BG=n \
  ./30-start-sender.sh
ssh -n $USER@$SERVER1_EXT "cd wallaroo ; ./utils/resilience-demo/received-wait-for.sh ./received.txt 11 2000 20"
if [ $? -ne 0 ]; then echo status check failed; exit 7; fi;

echo Run validator to check for sequence validity.
ssh -n $USER@$SERVER1_EXT "cd wallaroo; ./testing/correctness/apps/multi_partition_detector/validator/validator -e 2000  -i -k key_0,key_1,key_2,key_3,key_4,key_5,key_6,key_7,key_8,key_9,key_10"
STATUS=$?

echo Validation status was: $STATUS
exit $STATUS
