#!/bin/sh
set -x #echo on
export DEBIAN_FRONTEND=noninteractive
export TERM=linux

# grub-pc currently causes apt-get upgrade to pause indefinitely
# holding so it does not get upgraded
sudo apt-mark hold grub-pc
# Install common tools
sudo apt-get -y update
sudo apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
sudo apt-get install -y python3-dev build-essential python3-pip unzip zip curl \
                        libsnappy-dev liblz4-dev libz-dev libssl-dev \
                        cpuset numactl
sudo -H python -m pip install pytest==3.2.2
sudo -H python -m pip install --upgrade pip enum34

# Hot-unplug all virtual CPUS at startup
# Source: https://aws.amazon.com/blogs/compute/disabling-intel-hyper-threading-technology-on-amazon-linux/
echo 'for cpunum in $(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | \
	cut -s -d, -f2- | tr "," "\n" | sort -un)
      do
        echo 0 > /sys/devices/system/cpu/cpu$cpunum/online
      done
' | sudo tee -a /etc/rc.local
sudo chmod +x /etc/rc.local
