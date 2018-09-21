#!/bin/sh

. ./COMMON.sh

./99-stop-everything.sh
ssh -n $USER@$SERVER1_EXT "rm -f /tmp/${WALLAROO_NAME}* /tmp/run-dir/*" > /dev/null 2>&1 &
ssh -n $USER@$SERVER2_EXT "rm -f /tmp/${WALLAROO_NAME}* /tmp/run-dir/*" > /dev/null 2>&1 &
ssh -n $USER@$SERVER3_EXT "rm -f /tmp/${WALLAROO_NAME}* /tmp/run-dir/*" > /dev/null 2>&1 &
wait

. ./START-DOS-SERVER.sh

echo Start MUI
ssh -n $USER@$SERVER1_EXT "/home/ubuntu/wallaroo-tutorial/wallaroo-0.5.2/bin/metrics_ui/AppRun start" &
sleep 1

if [ ! -z "$START_RECEIVER_CMD" ]; then
    echo Start receiver via external var
    CMD=`eval echo $START_RECEIVER_CMD`
    #echo "CMD = $CMD"
    ssh -n $USER@$SERVER1_EXT "cd wallaroo ; $CMD > /tmp/run-dir/receiver.out 2>&1" > /dev/null 2>&1 &
else
    echo Start receiver
    ssh -n $USER@$SERVER1_EXT "cd wallaroo ; ./giles/receiver/receiver --ponythreads=1 --ponynoblock --ponypinasio -w -l ${SERVER1}:5555 > /tmp/run-dir/receiver.out 2>&1" > /dev/null 2>&1 &
    sleep 2
fi    

echo Start initializer
ssh -n $USER@$SERVER1_EXT "cd wallaroo ; $WALLAROO_BIN -i ${SERVER1}:${ORDERS_PORT},${SERVER1}:${NBBO_PORT} -o ${SERVER1}:5555 -m ${SERVER1}:5001 -c ${SERVER1}:12500 -d ${SERVER1}:12501 -t -e ${SERVER1}:5050 -w 2 $W_DOS_SERVER_ARG  --ponynoblock  > /tmp/run-dir/${WALLAROO_NAME}1.out 2>&1" > /dev/null 2>&1 &
sleep 2

echo Start worker2
ssh -n $USER@$SERVER2_EXT "cd wallaroo ; $WALLAROO_BIN -i ${SERVER1}:${ORDERS_PORT},${SERVER1}:${NBBO_PORT} -o ${SERVER1}:5555 -m ${SERVER1}:5001 -c ${SERVER1}:12500 -n worker2 --my-control ${SERVER2}:13131 --my-data ${SERVER2}:13132 $W_DOS_SERVER_ARG --ponynoblock > /tmp/run-dir/${WALLAROO_NAME}2.out 2>&1" > /dev/null 2>&1 &

for i in $SERVER1_EXT $SERVER2_EXT; do
    /bin/echo -n "Check Wallaroo worker on ${i}: "
    LIM=30
    C=0
    while [ $C -lt $LIM ]; do
        /bin/echo -n .
        ssh -n $USER@$i "grep III /tmp/run-dir/${WALLAROO_NAME}*out"
        if [ $? -eq 0 ]; then
            break
        fi
        C=`expr $C + 1`
    done
    if [ $C -ge $LIM ]; then
        echo TIMEOUT
        exit 1
    fi
done

exit 0
