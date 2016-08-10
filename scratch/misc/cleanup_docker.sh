#!/bin/bash

if [ $# -ne 1 ]; then
  echo "Must supply arguments"
  echo "1: IP Address"
  exit 1
fi

ip=${1}

docker --host=${ip}:2378 logs app-receiver

docker --host=${ip}:2378 kill metrics aui mui giles-sender-trades giles-sender-nbbo giles-receiver app-receiver worker-2 worker-1 leader dagon

docker --host=${ip}:2378 rm metrics aui mui giles-sender-trades giles-sender-nbbo giles-receiver app-receiver worker-2 worker-1 leader dagon

docker --host=tcp://${ip}:2378 network rm buffy-swarm

