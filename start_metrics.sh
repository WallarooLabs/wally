#!/bin/bash
set fail -o -e

TMPDIR=/tmp/market-spread-run/

if [ -z "$DOWNLOAD" ]; then
  DOWNLOAD=1
fi  

mkdir -p $TMPDIR/metrics_reporter_ui
mkdir -p $TMPDIR/market_spread_reports_ui
if [ "$DOWNLOAD"  == "1" ]; then
  wget -N https://s3.amazonaws.com/sendence-dev/wallaroo/ui-bins/metrics_reporter_ui.tar.gz -O $TMPDIR/metrics_reporter_ui.tar.gz
fi  
tar zxf $TMPDIR/metrics_reporter_ui.tar.gz -C $TMPDIR/metrics_reporter_ui

pushd $TMPDIR/metrics_reporter_ui > /dev/null
until [ exec 6<>/dev/tcp/127.0.0.1/4000 ]; do
  bin/metrics_reporter_ui start
  sleep 5
done
popd


read -n1 -r -p "press any key when you want to kill everything" key

pushd $TMPDIR/metrics_reporter_ui
bin/metrics_reporter_ui stop
popd
