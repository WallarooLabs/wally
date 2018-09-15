#!/bin/sh

VALIDATION_TOTAL=200
VALIDATION_MIDWAY=100

export START_RECEIVER_CMD='env PYTHONPATH="./testing/tools/integration" \
  python ./utils/resilience-demo/validation-receiver.py ${SERVER1}:5555 \
  '$VALIDATION_TOTAL' 3 600 ./received.txt'

export WALLAROO_BIN="./testing/correctness/apps/multi_partition_detector/multi_partition_detector"

export START_SENDER_CMD1='env PYTHONPATH="./testing/tools/integration" \
  python ./utils/resilience-demo/validation-sender.py ${SERVER1}:7000 \
  0 '$VALIDATION_MIDWAY' 100 0.05 3'
export START_SENDER_CMD2='env PYTHONPATH="./testing/tools/integration" \
  python ./utils/resilience-demo/validation-sender.py ${SERVER1}:7000 \
  '$VALIDATION_MIDWAY' '$VALIDATION_TOTAL' 100 0.05 3'

. ./COMMON.sh

echo To stop everything, run: env WALLAROO_BIN=$WALLAROO_BIN ./99-stop-everything.sh

./99-stop-everything.sh
ssh -n $USER@$SERVER1_EXT "rm -f /tmp/${WALLAROO_NAME}* /tmp/run-dir/*" > /dev/null 2>&1 &
ssh -n $USER@$SERVER2_EXT "rm -f /tmp/${WALLAROO_NAME}* /tmp/run-dir/*" > /dev/null 2>&1 &
ssh -n $USER@$SERVER3_EXT "rm -f /tmp/${WALLAROO_NAME}* /tmp/run-dir/*" > /dev/null 2>&1 &
ssh -n $USER@$SERVER4_EXT "rm -f /tmp/${WALLAROO_NAME}* /tmp/run-dir/*" > /dev/null 2>&1 &
wait

. ./START-DOS-SERVER.sh

echo Start MUI
ssh -n $USER@$SERVER1_EXT "/home/ubuntu/wallaroo-tutorial/wallaroo-0.5.2/bin/metrics_ui/AppRun start" &
sleep 1

if [ ! -z "$START_RECEIVER_CMD" ]; then
    echo Start receiver via external var
    CMD=`eval echo $START_RECEIVER_CMD`
    echo "CMD = $CMD"
    ssh -n $USER@$SERVER1_EXT "cd wallaroo ; $CMD > /tmp/run-dir/receiver.out 2>&1" > /dev/null 2>&1 &
else
    echo Start receiver
    ssh -n $USER@$SERVER1_EXT "cd wallaroo ; ./giles/receiver/receiver --ponythreads=1 --ponynoblock --ponypinasio -w -l ${SERVER1}:5555 > /tmp/run-dir/receiver.out 2>&1" > /dev/null 2>&1 &
    sleep 2
fi    

echo Start initializer
ssh -n $USER@$SERVER1_EXT "cd wallaroo ; ulimit -c unlimited; ulimit -a > /tmp/ulimit.out ; ( date ; $WALLAROO_BIN -i ${SERVER1}:${ORDERS_PORT} -o ${SERVER1}:5555 -m ${SERVER1}:5001 -c ${SERVER1}:12500 -d ${SERVER1}:12501 -t -e ${SERVER1}:5050      $W_DOS_SERVER_ARG --ponynoblock ; echo status was $? ; date) > /tmp/run-dir/${WALLAROO_NAME}1.out 2>&1" > /dev/null 2>&1 &
sleep 2

for i in $SERVER1_EXT; do
    /bin/echo -n "Check Wallaroo worker on ${i}: "
    while [ 1 ]; do 
        /bin/echo -n .
        ssh -n $USER@$i "grep III /tmp/run-dir/${WALLAROO_NAME}*out"
        if [ $? -eq 0 ]; then
            break
        fi
    done
done

##env START_SENDER_CMD="$START_SENDER_CMD1" START_SENDER_BG=n \
##    ./30-start-sender.sh
##echo First sender has finished; sleep 1
##echo BONUS SLEEP 5; sleep 5

echo Kill worker1
./40-kill-worker.sh 1
sleep 1

echo Restart initializer on server 1 with same TCP ports
ssh -n $USER@$SERVER1_EXT "mkdir -p /tmp/run-dir/OLD ; mv -v /tmp/run-dir/m* /tmp/run-dir/OLD"
ssh -n $USER@$SERVER1_EXT "cd wallaroo ; ulimit -c unlimited; ulimit -a > /tmp/ulimit.out ; ( date ; $WALLAROO_BIN -i ${SERVER1}:${ORDERS_PORT},${SERVER1}:${NBBO_PORT} -o ${SERVER1}:5555 -m ${SERVER1}:5001 -c ${SERVER1}:12500 -d ${SERVER1}:12501 -t -e ${SERVER1}:5050      $W_DOS_SERVER_ARG --ponynoblock ; echo status was $? ; date) > /tmp/run-dir/${WALLAROO_NAME}1b.out 2>&1" > /dev/null 2>&1 &

S=3; echo SLEEP for $S; sleep $S
echo EXIT 99 for bug demo purposes; exit 99

env START_SENDER_CMD="$START_SENDER_CMD2" START_SENDER_BG=n \
  ./30-start-sender.sh
echo Second sender has finished; sleep 1

