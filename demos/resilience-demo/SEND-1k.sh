#!/bin/sh

export START_SENDER_CMD1='env PYTHONPATH="./testing/tools/integration" \
  python ./demos/resilience-demo/validation-sender.py ${SERVER1}:7000 \
  0 500 100 0.05 11'
export START_SENDER_CMD1b='env PYTHONPATH="./testing/tools/integration" \
  python ./demos/resilience-demo/validation-sender.py ${SERVER1}:7000 \
  500 600 100 0.05 11'
export START_SENDER_CMD1c='env PYTHONPATH="./testing/tools/integration" \
  python ./demos/resilience-demo/validation-sender.py ${SERVER1}:7000 \
  600 700 100 0.05 11'
export START_SENDER_CMD1d='env PYTHONPATH="./testing/tools/integration" \
  python ./demos/resilience-demo/validation-sender.py ${SERVER1}:7000 \
  700 800 100 0.05 11'
export START_SENDER_CMD1e='env PYTHONPATH="./testing/tools/integration" \
  python ./demos/resilience-demo/validation-sender.py ${SERVER1}:7000 \
  800 900 100 0.05 11'
export START_SENDER_CMD1f='env PYTHONPATH="./testing/tools/integration" \
  python ./demos/resilience-demo/validation-sender.py ${SERVER1}:7000 \
  900 1000 100 0.05 11'

ssh -n $USER@$SERVER1_EXT "cd wallaroo ; ./demos/resilience-demo/received-wait-for.sh ./received.txt 11 500 20" & P2=$!
env START_SENDER_CMD="$START_SENDER_CMD1" START_SENDER_BG=n \
    ./30-start-sender.sh & P1=$!
wait $P2 ; if [ $? -ne 0 ]; then echo status check failed; exit 7; fi; wait $P1

ssh -n $USER@$SERVER1_EXT "cd wallaroo ; ./demos/resilience-demo/received-wait-for.sh ./received.txt 11 600 20" & P2=$!
env START_SENDER_CMD="$START_SENDER_CMD1b" START_SENDER_BG=n \
    ./30-start-sender.sh & P1=$!
wait $P2 ; if [ $? -ne 0 ]; then echo status check failed; exit 7; fi; wait $P1

ssh -n $USER@$SERVER1_EXT "cd wallaroo ; ./demos/resilience-demo/received-wait-for.sh ./received.txt 11 700 20" & P2=$!
env START_SENDER_CMD="$START_SENDER_CMD1c" START_SENDER_BG=n \
    ./30-start-sender.sh & P1=$!
wait $P2 ; if [ $? -ne 0 ]; then echo status check failed; exit 7; fi; wait $P1

ssh -n $USER@$SERVER1_EXT "cd wallaroo ; ./demos/resilience-demo/received-wait-for.sh ./received.txt 11 800 20" & P2=$!
env START_SENDER_CMD="$START_SENDER_CMD1d" START_SENDER_BG=n \
    ./30-start-sender.sh & P1=$!
wait $P2 ; if [ $? -ne 0 ]; then echo status check failed; exit 7; fi; wait $P1

ssh -n $USER@$SERVER1_EXT "cd wallaroo ; ./demos/resilience-demo/received-wait-for.sh ./received.txt 11 900 20" & P2=$!
env START_SENDER_CMD="$START_SENDER_CMD1e" START_SENDER_BG=n \
    ./30-start-sender.sh & P1=$!
wait $P2 ; if [ $? -ne 0 ]; then echo status check failed; exit 7; fi; wait $P1

ssh -n $USER@$SERVER1_EXT "cd wallaroo ; ./demos/resilience-demo/received-wait-for.sh ./received.txt 11 1000 20" & P2=$!
env START_SENDER_CMD="$START_SENDER_CMD1f" START_SENDER_BG=n \
    ./30-start-sender.sh & P1=$!
wait $P2 ; if [ $? -ne 0 ]; then echo status check failed; exit 7; fi; wait $P1

