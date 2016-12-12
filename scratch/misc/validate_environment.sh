#!/bin/bash

CPU0_SIBLINGS=$(cat /sys/devices/system/cpu/cpu0/topology/thread_siblings_list)
SYSTEM_CPUS=$(sudo cset set -l | grep system | awk '{print $2}')
NET_DRIVER=$(ifconfig | grep Ethernet | awk '{print $1}' | xargs -L 1 ethtool -i | grep 'vif')

if [ "" != "${NET_DRIVER}" ]; then
  echo -e "\033[01;31mWARNING: network driver is 'vif' which is not ideal!\033[0m"
else
  echo -e "\033[01;32mNetwork driver is set up correctly for optimal performance.\033[0m"
fi

if [ "${CPU0_SIBLINGS}" != "${SYSTEM_CPUS}" ]; then
  echo -e "\033[01;31mWARNING: system cpu isolation is not ideal! It is '${SYSTEM_CPUS}' when expected was '${CPU0_SIBLINGS}'.\033[0m"
else
  echo -e "\033[01;32mSystem cpu isolation set up as expected for optimal performance.\033[0m"
fi

