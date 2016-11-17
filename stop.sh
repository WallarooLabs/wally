#!/bin/bash -vx

pidof nc | xargs sudo kill

ps aux | grep '/home/ubuntu/buffy/apps/market-test/market-test' | grep -v 'grep' | awk '{print $2}' | xargs sudo kill

ps aux | grep '/home/ubuntu/buffy/giles/sender/sender' | grep -v 'grep' | awk '{print $2}' | xargs sudo kill

docker restart mui

