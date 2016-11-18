#!/bin/bash -vx


if [ "$1" == "help" ]; then
  echo "$0 noblock|block useperf|noperf r3k|2100|1400|700 NUM_BUFFY_THREADS"
  exit
fi


NO_BLOCK=""
if [ "$1" == "noblock" ]; then
  NO_BLOCK="--ponynoblock"
fi

PERF=""
if [ "$2" == "useperf" ]; then
  PERF="perf record -F 999 --call-graph dwarf --"
fi

SYMBOLS="${3:-r3k}"

NUM_THREADS=${4:-4}

cd ~/buffy
sudo cset proc -s user -e numactl -- -C 1-${NUM_THREADS},17 chrt -f 80 ${PERF} ~/buffy/apps/market-test/market-test -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -e 150000000000 -n nodename --ponythreads ${NUM_THREADS} --ponypinasio $NO_BLOCK &

sleep 2

nc -l 5555 > /dev/null &

cd ~/buffy
sudo cset proc -s user -e numactl -- -C 15,17 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7000 -m 1000 -s 300 -i 2_500_000 -f ~/buffy/demos/marketspread/initial-nbbo-fixish.msg -r --ponythreads=1 -y -g 46 --ponypinasio -w $NO_BLOCK &

cd ~/buffy
sudo cset proc -s user -e numactl -- -C 15,17 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7000 -m 100000000000 -s 300 -i 2_500_000 -f ~/buffy/demos/marketspread/350k-nbbo-fixish.msg -r --ponythreads=1 -y -g 46 --ponypinasio -w $NO_BLOCK &

sleep 2

cd ~/buffy
sudo cset proc -s user -e numactl -- -C 16,17 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7001 -m 50000000000 -s 300 -i 5_000_000 -f ~/buffy/demos/marketspread/350k-orders-fixish.msg -r --ponythreads=1 -y -g 57 --ponypinasio -w $NO_BLOCK &



