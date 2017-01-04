# Performance Testing on AWS/Packet

If you have not followed the setup instructions in the orchestration/terraform [README](https://github.com/Sendence/buffy/tree/master/orchestration/terraform) please do so before continuing.

##Configuring Cluster:

Once set up, an AWS cluster can be started with the following command:

```
make cluster cluster_name=<YOUR_CLUSTER_NAME> mem_required=30 cpus_required=36 num_followers=0 force_instance=c4.8xlarge spot_bid_factor=100 ansible_system_cpus=0,18 ansible_isolcpus=false no_spot=true
```

For resilience runs, use:
```
make cluster cluster_name=<YOUR_CLUSTER_NAME> num_followers=0 force_instance=i2.8xlarge spot_bid_factor=100 ansible_system_cpus=0,16 ansible_isolcpus=false no_spot=true
```


A packet cluster with this command:
```
make cluster cluster_name=<YOUR_CLUSTER_NAME> provider=packet region=ewr1 use_automagic_instances=false num_followers=0 ansible_install_devtools=true ansible_system_cpus=0,24 force_instance=baremetal_2 ansible_isolcpus=true
```


You'll get a response ending with something similar to this if successful:
```PLAY RECAP *********************************************************************
54.165.9.39                : ok=70   changed=39   unreachable=0    failed=0```

You can SSH into the AWS machine using:
```
ssh -i ~/.ssh/ec2/us-east-1.pem ubuntu@<IP_ADDRESS>
```

And you can SSH into the Packet machine using:
```
ssh -i ~/.ssh/ec2/us-east-1.pem sendence@<IP_ADDRESS>
```

##Performance Testing:

### Metrics UI

You need to create a docker network for the UI's with the following command:
```
docker network create buffy-leader
```

To run the Metrics UI:
```
docker run -d -u root --cpuset-cpus 0,18 --privileged  \
-v /usr/bin:/usr/bin:ro   -v /var/run/docker.sock:/var/run/docker.sock \
-v /bin:/bin:ro  -v /lib:/lib:ro  -v /lib64:/lib64:ro  -v /usr:/usr:ro  \
-v /tmp:/apps/metrics_reporter_ui/log  \
-p 0.0.0.0:4000:4000 -p 0.0.0.0:5001:5001 \
-e "BINS_TYPE=demo" -e "RELX_REPLACE_OS_VARS=true" \
--name mui -h mui --net=buffy-leader \
docker.sendence.com:5043/wallaroo-metrics-ui-new:latest
```

#### Restarting UIs
```
docker stop mui && docker start mui
```


###Running Market Spread

You'll need to clone the repo:
```
git clone https://github.com/sendence/buffy.git
```

To build Market Spread:
```
make arch=amd64 build-apps-market-spread
```

To build Giles Sender:
```
make build-giles-sender arch=amd64 ponyc_tag=sendence-14.0.5-release
```

To build Giles Receiver:
```
make build-giles-receiver arch=amd64 ponyc_tag=sendence-14.0.5-release
```

###AWS
to run the Market Spread application you must be in it's directory.

####SINGLE WORKER market spread:

#####350 Symbols:
Giles receiver needs to be running before marketspread:
```
sudo cset proc -s user -e numactl -- -C 14 chrt -f 80 ~/buffy/giles/receiver/receiver --ponythreads=1 --ponynoblock -w -l 127.0.0.1:5555
```

```
sudo cset proc -s user -e numactl -- -C 1-4,17 chrt -f 80 ./market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 --ponythreads 4 --ponypinasio --ponynoblock -c 127.0.0.1:12500 -d 127.0.0.1:12501
```

To run the NBBO Sender: (must be started before Orders so that the initial NBBO can be set)
```
sudo cset proc -s user -e numactl -- -C 15,17 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7001 -m 10000000000 -s 300 -i 2_500_000 -f ~/buffy/demos/marketspread/350k-nbbo-fixish.msg -r --ponythreads=1 -y -g 46 --ponypinasio -w —ponynoblock
```

To run the Orders Sender:
```
sudo cset proc -s user -e numactl -- -C 16,17 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7000 -m 5000000000 -s 300 -i 5_000_000 -f ~/buffy/demos/marketspread/350k-orders-fixish.msg -r --ponythreads=1 -y -g 57 --ponypinasio -w —ponynoblock
```


####2 WORKER market spread (in order)
Giles receiver needs to be running before marketspread:
```
sudo cset proc -s user -e numactl -- -C 14 chrt -f 80 ~/buffy/giles/receiver/receiver --ponythreads=1 --ponynoblock -w -l 127.0.0.1:5555
```

```
sudo cset proc -s user -e numactl -- -C 1-4,17 chrt -f 80 ./market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:12500 -d 127.0.0.1:12501 --ponythreads 4 --ponypinasio --ponynoblock -w 2 -t

sudo cset proc -s user -e numactl -- -C 5-8,17 chrt -f 80 ./market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:12500 -d 127.0.0.1:12501 --ponythreads 4 --ponypinasio --ponynoblock -w 2 -n worker2
```

To run the NBBO Sender: (must be started before Orders so that the initial NBBO can be set)
```
sudo cset proc -s user -e numactl -- -C 15,17 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7001 -m 10000000000 -s 300 -i 2_500_000 -f ~/buffy/demos/marketspread/350k-nbbo-fixish.msg -r --ponythreads=1 -y -g 46 --ponypinasio -w —ponynoblock
```

To run the Orders Sender:
```
sudo cset proc -s user -e numactl -- -C 16,17 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7000 -m 5000000000 -s 300 -i 5_000_000 -f ~/buffy/demos/marketspread/350k-orders-fixish.msg -r --ponythreads=1 -y -g 57 --ponypinasio -w —ponynoblock
```

#####R3K Symbols:
Giles receiver needs to be running before marketspread:
```
sudo cset proc -s user -e numactl -- -C 14 chrt -f 80 ~/buffy/giles/receiver/receiver --ponythreads=1 --ponynoblock -w -l 127.0.0.1:5555
```

```
sudo cset proc -s user -e numactl -- -C 1-4,17 chrt -f 80 ./market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -f ../../demos/marketspread/r3k-initial-nbbo-fixish.msg -s ../../demos/marketspread/r3k-legal-symbols.msg --ponythreads 4 --ponypinasio --ponynoblock -c 127.0.0.1:12500 -d 127.0.0.1:12501
```

To run the NBBO Sender: (must be started before Orders so that the initial NBBO can be set)
```
sudo cset proc -s user -e numactl -- -C 15,17 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7001 -m 10000000000 -s 300 -i 2_500_000 -f ~/buffy/demos/marketspread/350k-nbbo-fixish.msg -r --ponythreads=1 -y -g 46 --ponypinasio -w —ponynoblock
```

To run the Orders Sender:
```
sudo cset proc -s user -e numactl -- -C 16,17 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7000 -m 5000000000 -s 300 -i 5_000_000 -f ~/buffy/demos/marketspread/350k-orders-fixish.msg -r --ponythreads=1 -y -g 57 --ponypinasio -w —ponynoblock
```


####2 WORKER market spread (in order)
Giles receiver needs to be running before marketspread:
```
sudo cset proc -s user -e numactl -- -C 14 chrt -f 80 ~/buffy/giles/receiver/receiver --ponythreads=1 --ponynoblock -w -l 127.0.0.1:5555
```

```
sudo cset proc -s user -e numactl -- -C 1-4,17 chrt -f 80 ./market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:12500 -d 127.0.0.1:12501 --ponythreads 4 --ponypinasio --ponynoblock -w 2 -t

sudo cset proc -s user -e numactl -- -C 5-8,17 chrt -f 80 ./market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:12500 -d 127.0.0.1:12501 --ponythreads 4 --ponypinasio --ponynoblock -w 2 -n worker2
```

To run the NBBO Sender: (must be started before Orders so that the initial NBBO can be set)
```
sudo cset proc -s user -e numactl -- -C 15,17 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7001 -m 10000000000 -s 300 -i 2_500_000 -f ~/buffy/demos/marketspread/350k-nbbo-fixish.msg -r --ponythreads=1 -y -g 46 --ponypinasio -w —ponynoblock
```

To run the Orders Sender:
```
sudo cset proc -s user -e numactl -- -C 16,17 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7000 -m 5000000000 -s 300 -i 5_000_000 -f ~/buffy/demos/marketspread/350k-orders-fixish.msg -r --ponythreads=1 -y -g 57 --ponypinasio -w —ponynoblock
```

####2 MACHINE market spread (2 workers)
Giles receiver needs to be running before marketspread (can be on either machine, but for consistency put it on
machine 2):
```
cd ~/buffy
sudo cset proc -s user -e numactl -- -C 14 chrt -f 80 ~/buffy/giles/receiver/receiver --ponythreads=1 --ponynoblock -w -l 0.0.0.0:5555
```

Make sure you have the same binary on both machines or you'll get segfaults with serialization.

Machine 1:
```
sudo cset proc -s user -e numactl -- -C 1-12,17 chrt -f 80 ~/buffy/apps/market-spread/market-spread -i 0.0.0.0:7000,0.0.0.0:7001 -o <MACHINE IP ADDRESS FOR OUTPUT>:5555 -m <MACHINE IP ADDRESS FOR METRICS>:5001 -c 0.0.0.0:12500 -d 0.0.0.0:12501 --ponythreads 12 --ponypinasio --ponynoblock -t -w 2
```

Machine 2:
```
sudo cset proc -s user -e numactl -- -C 1-12,17 chrt -f 80 ~/buffy/apps/market-spread/market-spread -i 0.0.0.0:7000,0.0.0.0:7001 -o <MACHINE IP ADDRESS FOR OUTPUT>:5555 -m <MACHINE IP ADDRESS FOR METRICS>:5001 -c 0.0.0.0:12500 -d 0.0.0.0:12501 --ponythreads 12 --ponypinasio --ponynoblock -n worker2 -w 2
```

###Packet
Giles receiver needs to be running before marketspread:
```
sudo cset proc -s user -e numactl -- -C 8 chrt -f 80 ~/buffy/giles/receiver/receiver --ponythreads=1 --ponynoblock -w -l 127.0.0.1:5555
```

to run the Market Spread application you must be in it's directory:

```
sudo cset proc -s user -e numactl -- -C 1-4,7 chrt -f 80 ./market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -e 150000000 --ponythreads 4 --ponypinasio
```

To run the NBBO Sender: (must be started before Orders so that the initial NBBO can be set)

```
sudo cset proc -s user -e numactl -- -C 5,7 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7001 -m 100000000 -s 300 -i 2_500_000 -f ~/buffy/demos/marketspread/350k-nbbo-fixish.msg -r --ponythreads=1 -y -g 46 --ponypinasio -w —ponynoblock
```

To run the Orders Sender:

```
sudo cset proc -s user -e numactl -- -C 6,7 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7000 -m 50000000 -s 300 -i 5_000_000 -f ~/buffy/demos/marketspread/350k-orders-fixish.msg -r --ponythreads=1 -y -g 57 --ponypinasio -w —ponynoblock
```


###Running with System Tap (stap) on Linux
Install stap:
```
sudo apt-get install -y systemtap systemtap-runtime systemtap-sdt-dev
```

Get the `dh_actor_telemetry` ponyc branch.

Compile ponyc:
```
sudo make install LLVM_CONFIG=~/clang+llvm-3.8.1-x86_64-linux-gnu-ubuntu-16.04/bin/llvm-config use=dtrace
```

Model for running stap (you need to fill in the -c argument as in the example below this one):
```
stap ~/ponyc/examples/systemtap/actor-telemetry-heap-only.stp -o stap-out.txt -g --suppress-time-limits -c 'command + args in a string'
```


#### Analyzing output
Get sizes for gc
```grep gc_heapsize telemout.txt | awk -F: '{print $2}' | sort -n| tail```

Get sizes for alloc
```grep alloc_heapsize telemout.txt | awk -F: '{print $2}' | sort -n | tail```

Get type_ids. Replace the values with sizes you're looking for.
```egrep '500405056|478746624|2997216|2599456|1185184|135232' -B 4 telemout.txt```

Find type_id type names by doing
```ponyc -d -r=ir``` and inspecting the output <APP-NAME.ll>

Running 2 worker market spread:
```
sudo cset proc -s user -e numactl -- -C 1-4,17 chrt -f 80 stap /home/ubuntu/ponyc/examples/systemtap/actor-telemetry-heap-only.stp -o market-stap-w1.txt -g --suppress-time-limits -c '~/buffy/apps/market-spread/market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:12500 -d 127.0.0.1:12501 -f ../../demos/marketspread/r3k-initial-nbbo-fixish.msg -s ../../demos/marketspread/r3k-legal-symbols.msg --ponythreads 4 --ponypinasio --ponynoblock -w 2 -t'

sudo cset proc -s user -e numactl -- -C 5-8,17 chrt -f 80 stap /home/ubuntu/ponyc/examples/systemtap/actor-telemetry-heap-only.stp -o market-stap-w2.txt -g --suppress-time-limits -c '~/buffy/apps/market-spread/market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:12500 -d 127.0.0.1:12501 -f ../../demos/marketspread/r3k-initial-nbbo-fixish.msg -s ../../demos/marketspread/r3k-legal-symbols.msg --ponythreads 4 --ponypinasio --ponynoblock -w 2'
```

