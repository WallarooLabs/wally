#!/bin/bash

CPU0_SIBLINGS=$(cat /sys/devices/system/cpu/cpu0/topology/thread_siblings_list)
SYSTEM_CPUS=$(sudo cset set -l | grep system | awk '{print $2}')
NET_DRIVER=$(ifconfig | grep Ethernet | awk '{print $1}' | xargs -L 1 ethtool -i | grep 'vif')
CLOCKSOURCE=$(cat /sys/devices/system/clocksource/clocksource0/current_clocksource)
THP=$(cat /sys/kernel/mm/transparent_hugepage/enabled | awk -F[ '{print $2}' | awk -F] '{print $1}')
SWAPPINESS=$(sysctl -n vm.swappiness)
CPU_GOV=$(cat /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor)
CPU_TURBO=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo)
HT_LIMITED=$(cat /proc/cmdline | grep -o maxcpus=.*)
TSC_RELIABLE=$(cat /proc/cmdline | grep -o tsc=reliable)

if [ "performance" != "${CPU_GOV}" ]; then
  if [ "" == "${CPU_GOV}" ]; then
    echo -e "\033[01;31mWARNING: CPU governor not under our control which is not ideal!\033[0m"
  else
    echo -e "\033[01;31mWARNING: CPU governor is '${CPU_GOV}' which is not ideal!\033[0m"
  fi
else
  echo -e "\033[01;32mCPU governor is set up correctly (${CPU_GOV}) for optimal performance.\033[0m"
fi

if [ "1" != "${CPU_TURBO}" ]; then
  if [ "" == "${CPU_TURBO}" ]; then
    echo -e "\033[01;31mWARNING: CPU turbo boost is not under our control which is not ideal because the hardware can change cpu frequencies during a run!\033[0m"
  else
    echo -e "\033[01;31mWARNING: CPU turbo boost is enabled which is not ideal because the hardware can change cpu frequencies during a run!\033[0m"
  fi
else
  echo -e "\033[01;32mCPU turbo boost is disabled for optimal performance so the hardware can't change cpu frequencies during a run.\033[0m"
fi

if [ "" == "${HT_LIMITED}" ]; then
  echo -e "\033[01;31mWARNING: Hyperthreaded cpus are still enabled which is not ideal!\033[0m"
else
  echo -e "\033[01;32mHyperthreaded cpus are disabled/set up correctly for optimal performance.\033[0m"
fi

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

if [ "tsc" != "${CLOCKSOURCE}" ]; then
  echo -e "\033[01;31mWARNING: system clocksource is '${CLOCKSOURCE}' which is not ideal! It should be 'tsc'.\033[0m"
else
  echo -e "\033[01;32mSystem clocksource is set up correctly for optimal performance.\033[0m"
fi

if [ "" == "${TSC_RELIABLE}" ]; then
  echo -e "\033[01;31mWARNING: tsc clocksource isn't set as reliable which is not ideal because the system might mark tsc as unreliable!\033[0m"
else
  echo -e "\033[01;32mtsc clocksource is set as reliable correctly for optimal performance.\033[0m"
fi

if [ "never" != "${THP}" ]; then
  echo -e "\033[01;31mWARNING: transparent hugepages is not disabled which is not ideal! It is set to '${THP}' instead of 'never'.\033[0m"
else
  echo -e "\033[01;32mTransparent hugepages is disabled as required for optimal performance.\033[0m"
fi

if [ "0" != "${SWAPPINESS}" ]; then
  echo -e "\033[01;31mWARNING: swappiness is not 0 which is not ideal! It is set to '${SWAPPINESS}' instead of '0'.\033[0m"
else
  echo -e "\033[01;32mSwappiness is set to 0 as required for optimal performance.\033[0m"
fi

