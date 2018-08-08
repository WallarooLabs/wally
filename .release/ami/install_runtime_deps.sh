#!/bin/sh
sudo apt-get update && sudo apt-get -y upgrade
sudo apt-get install -y libsnappy-dev liblz4-dev libz-dev \
     libssl-dev python-dev build-essential python-pip unzip

sudo -H python -m pip install pytest==3.2.2
sudo -H python -m pip install --upgrade pip enum34
