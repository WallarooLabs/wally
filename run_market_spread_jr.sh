#!/bin/bash
set fail -o -e

TMPDIR=/tmp/market-spread-jr-run/
SCREEN_SESSION_NAME="RUNNING_MARKET_SPREAD_JR"
DOWNLOAD=0

mkdir -p $TMPDIR/metrics_reporter_ui
mkdir -p $TMPDIR/market_spread_reports_ui
wget -N https://s3.amazonaws.com/sendence-dev/wallaroo/ui-bins/market_spread_reports_ui.tar.gz -O $DESTDIR/market_spread_reports_ui.tar.gz
wget -N https://s3.amazonaws.com/sendence-dev/wallaroo/ui-bins/metrics_reporter_ui.tar.gz -O $DESTDIR/metrics_reporter_ui.tar.gz

tar zxf $TMPDIR/market_spread_reports_ui.tar.gz -C $TMPDIR/market_spread_reports_ui
tar zxf $TMPDIR/metrics_reporter_ui.tar.gz -C $TMPDIR/metrics_reporter_ui

make build-apps-market-spread-jr
make build-giles-sender

screen -dmS $SCREEN_SESSION_NAME

pushd $TMPDIR/metrics_reporter_ui
until [ exec 6<>/dev/tcp/127.0.0.1/4000 ]; do
  bin/metrics_reporter_ui start
  sleep 5
done
cd $TMPDIR/market_spread_reports_ui
until [ exec 6<>/dev/tcp/127.0.0.1/4001 ]; do
  bin/market_spread_reports_ui start
  sleep 5
done
popd

screen -S $SCREEN_SESSION_NAME -p 0 -X stuff "apps/market-spread-jr/market-spread-jr -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -f ../../demos/marketspread/initial-nbbo-fixish.msg -e 150000000 -n node-name
"

screen -S $SCREEN_SESSION_NAME -X screen 1
screen -S $SCREEN_SESSION_NAME -p 1 -X stuff "giles/sender/sender -b 127.0.0.1:7000 -m 100000000 -s 300 -i 2_500_000 -f demos/marketspread/350k-nbbo-fixish.msg -r --ponythreads=1 -y -g 46 -w
"

screen -S $SCREEN_SESSION_NAME -X screen 2
screen -S $SCREEN_SESSION_NAME -p 2 -X stuff "giles/sender/sender -b 127.0.0.1:7001 -m 50000000 -s 300 -i 5_000_000 -f demos/marketspread/350k-orders-fixish.msg -r --ponythreads=1 -y -g 57 -w
"

read -n1 -r -p "run \`screen -r $SCREEN_SESSION_NAME\` to see what's happening, and press any key when you want to kill everything" key

pushd $TMPDIR/metrics_reporter_ui
bin/metrics_reporter_ui stop
cd $TMPDIR/market_spread_reports_ui
bin/market_spread_reports_ui stop
popd

screen -X -S $SCREEN_SESSION_NAME quit
