#!/bin/sh

# Install common tools
sudo apt-get update && sudo apt-get -y upgrade
sudo apt-get install -y python-dev build-essential python-pip unzip zip curl \
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
