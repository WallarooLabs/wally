#!/bin/bash
set -euox pipefail

# kernel tweaks
# misc
echo tsc > /sys/devices/system/clocksource/clocksource0/current_clocksource # change clocksource
echo never > /sys/kernel/mm/transparent_hugepage/enabled # disable transparent hugepages
echo 1000000000 > /proc/sys/vm/nr_overcommit_hugepages # enable hugepages
sysctl -w vm.min_free_kbytes=`cat /proc/meminfo | grep MemTotal | awk '{print ($2/4 < 8000000) ? $2/4 : 8000000}'`   # keep memory in reserve for when processes request it
sysctl -w vm.swappiness=0                       # change swappiness
sysctl -w vm.zone_reclaim_mode=0                       # disable zone reclaim on numa nodes
sysctl -w kernel.sched_migration_cost_ns=5000000
sysctl -w kernel.sched_autogroup_enabled=0
sysctl -w kernel.sched_latency_ns=36000000
sysctl -w kernel.sched_min_granularity_ns=10000000

# networking stuff
sysctl -w net.core.somaxconn=2048
sysctl -w net.core.netdev_max_backlog=30000
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216
sysctl -w net.ipv4.tcp_wmem='4096 12582912 16777216'
sysctl -w net.ipv4.tcp_rmem='4096 12582912 16777216'
sysctl -w net.ipv4.tcp_max_syn_backlog=8096
sysctl -w net.ipv4.tcp_slow_start_after_idle=0
sysctl -w net.ipv4.tcp_tw_reuse=1
sysctl -w net.ipv4.ip_local_port_range='10240 65535'
sysctl -w net.ipv4.tcp_abort_on_overflow=1    # maybe
sysctl -w net.ipv4.tcp_mtu_probing=1
sysctl -w net.ipv4.tcp_timestamps=1
sysctl -w net.ipv4.tcp_low_latency=1
sysctl -w net.core.default_qdisc=fq_codel
sysctl -w net.ipv4.tcp_window_scaling=1
sysctl -w net.ipv4.tcp_max_tw_buckets=7200000
sysctl -w net.ipv4.tcp_sack=0
sysctl -w net.ipv4.tcp_fin_timeout=15
sysctl -w net.ipv4.tcp_moderate_rcvbuf=1
sysctl -w net.core.rps_sock_flow_entries=65536

sys_cpus=`cset set -l -r -x system | grep '/system$' | awk '{print $2}'`
interface=`ifconfig |  grep '^e' | awk '{print $1}'`

if [ -a /sys/class/net/${interface}/queues/rx-0/rps_flow_cnt ]; then
  echo 32768 > /sys/class/net/${interface}/queues/rx-0/rps_flow_cnt
  echo ${sys_cpus} > /sys/class/net/${interface}/queues/rx-0/rps_cpus
fi

if [ -a /sys/class/net/${interface}/queues/rx-1/rps_flow_cnt ]; then
  echo 32768 > /sys/class/net/${interface}/queues/rx-1/rps_flow_cnt
  echo ${sys_cpus} > /sys/class/net/${interface}/queues/rx-1/rps_cpus
fi

if [ -a /sys/class/net/${interface}/queues/tx-0/xps_cpus ]; then
  echo FFFFFFFF > /sys/class/net/${interface}/queues/tx-0/xps_cpus
fi

if [ -a /sys/class/net/${interface}/queues/tx-1/xps_cpus ]; then
  echo FFFFFFFF > /sys/class/net/${interface}/queues/tx-1/xps_cpus
fi

for irq in `cat /proc/interrupts| grep ${interface} | awk -F: '{print $1}'`; do
  echo ${sys_cpus} > /proc/irq/${irq}/smp_affinity
done

#if tc qdisc show dev ${interface} | grep pfifo_fast; then
#  tc qdisc add dev ${interface} root fq_codel
#fi

sysctl -w net.core.dev_weight=600
sysctl -w net.core.netdev_budget=600
sysctl -w net.core.netdev_tstamp_prequeue=1
sysctl -w net.ipv4.tcp_congestion_control=dctcp
sysctl -w net.ipv4.tcp_ecn=1

sysctl -w net.ipv4.tcp_fastopen=3

sysctl -w net.core.busy_poll=50 # spend cpu for lower latency
sysctl -w net.core.busy_read=50 # spend cpu for lower latency


# filesystem stuff
sysctl -w vm.dirty_ratio=80                     # from 40
sysctl -w vm.dirty_bytes=2147483648                     # from 0
sysctl -w vm.dirty_background_bytes=268435456                     # from 0
sysctl -w vm.dirty_background_ratio=5           # from 10
sysctl -w vm.dirty_expire_centisecs=12000       # from 3000

for drive_path in /dev/xvd[a-z]
do
  drive=`basename ${drive_path}`
  if [ -b "${drive_path}" ]; then
    echo 2 > /sys/block/${drive}/queue/rq_affinity
    echo noop > /sys/block/${drive}/queue/scheduler
    if [ `cat /sys/block/${drive}/device/modalias` != xen:vbd ]; then
      echo 256 > /sys/block/${drive}/queue/nr_requests
    fi
    echo 256 > /sys/block/${drive}/queue/read_ahead_kb
    echo 0 > /sys/block/${drive}/queue/add_random
    echo 0 > /sys/block/${drive}/queue/rotational
  fi
done

for drive_path in /dev/nvme*n1
do
  drive=`basename ${drive_path}`
  if [ -b "${drive_path}" ]; then
    echo 2 > /sys/block/${drive}/queue/rq_affinity
    echo 256 > /sys/block/${drive}/queue/read_ahead_kb
    echo 0 > /sys/block/${drive}/queue/add_random
    echo 0 > /sys/block/${drive}/queue/rotational
  fi
done

# apply changes
sysctl -p # apply changed settings

# from: https://www.ibm.com/developerworks/community/wikis/home?lang=en#!/wiki/W51a7ffcf4dfd_4b40_9d82_446ebc23c550/page/Linux%20on%20Power%20-%20Low%20Latency%20Tuning
# Make sure to set the realtime bandwidth reservation to zero, or even real-time tasks will be asks to step aside for a bit
echo 0 > /proc/sys/kernel/sched_rt_runtime_us

# If a soft limit is set for the maximum realtime priority which is less than the hard limit and needs to be raised, the "ulimit -r" command can do so
ulimit -r 90

# set performance cpu governor and default cpu fequency
if [ -a /sys/devices/system/cpu/cpu0/cpufreq ]; then
  cpupower -c all frequency-set -g performance --min $(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq) --max $(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq)
fi

# cpu frequency related stuff
if [ -a /sys/devices/system/cpu/cpu0/cpufreq ]; then
  echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo # disable turbo boost to limit cpu frequency variations
fi

##ethtool based tweaks
ethtool -G ${interface} rx 4096 tx 4096 || true # for to always succeed because if value is correct already it fails
#ethtool -K eth0 gso off # don't disable becuase only used when sending large packets and helps offload work from cpu
ethtool -K ${interface} gro off # disable because this slows packet delivery up network stack
#ethtool -K eth0 tso off # don't disable becuase only used when sending large packets and helps offload work from cpu
ethtool -C ${interface} rx-usecs 0 || true # for to always succeed because if value is correct already it fails
