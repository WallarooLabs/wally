#!/bin/bash -vx

cd ~/buffy

pidof nc | xargs sudo kill

ps aux | grep "`pwd`/apps/market-test/market-test" | grep -v 'grep' | awk '{print $2}' | xargs sudo kill

ps aux | grep "`pwd`/giles/sender/sender" | grep -v 'grep' | awk '{print $2}' | xargs sudo kill

if [ -e /etc/redhat-release ]; then
  ~/mui/bin/metrics_reporter_ui stop
  ~/mui/bin/metrics_reporter_ui start
else
  docker restart mui
fi

