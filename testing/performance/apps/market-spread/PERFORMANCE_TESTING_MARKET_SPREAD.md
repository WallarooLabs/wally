# Wallaroo Market Spread Single Machine Performance Testing on AWS

If you have not followed the setup instructions in the orchestration/terraform [README](https://github.com/Sendence/wallaroo/tree/master/orchestration/terraform) please do so before continuing.

## Configuring Cluster:

Before configuring your cluster, make sure you are in
your `orchestration/terraform` directory.

Once set up, an AWS cluster can be started with the following command:

```bash
make cluster cluster_name=<YOUR_CLUSTER_NAME> mem_required=30 cpus_required=36 num_followers=0 force_instance=c4.8xlarge spot_bid_factor=100 ansible_system_cpus=0,18 ansible_isolcpus=false no_spot=true
```

You'll get a response ending with something similar to this if successful:

```bash
PLAY RECAP *********************************************************************
54.165.9.39                : ok=70   changed=39   unreachable=0    failed=0
```

You can SSH into the AWS machine using:

```bash
ssh -i ~/.ssh/ec2/us-east-1.pem ubuntu@<IP_ADDRESS>
```

### Clone Wallaroo repo

You'll need to clone the repo:

```
git clone https://github.com/sendence/wallaroo.git
```

### Verify optimal setup

```bash
~/wallaroo/orchestration/validate_environment.sh
```

You should see:

```bash
CPU governor is set up correctly (performance) for optimal performance.
CPU turbo boost is disabled for optimal performance so the hardware can't change cpu frequencies during a run.
Hyperthreaded cpus are disabled/set up correctly for optimal performance.
Network driver is set up correctly for optimal performance.
System cpu isolation set up as expected for optimal performance.
System clocksource is set up correctly for optimal performance.
tsc clocksource is set as reliable correctly for optimal performance.
Transparent hugepages is disabled as required for optimal performance.
Swappiness is set to 0 as required for optimal performance.
```

### Startup the Metrics UI

You need to create a docker network for the UI's with the following command:

```bash
docker network create buffy-leader
```

To run the Metrics UI:

```bash
docker run -d -u root --cpuset-cpus 0,18 --privileged  \
-v /usr/bin:/usr/bin:ro   -v /var/run/docker.sock:/var/run/docker.sock \
-v /bin:/bin:ro  -v /lib:/lib:ro  -v /lib64:/lib64:ro  -v /usr:/usr:ro  \
-v /tmp:/apps/metrics_reporter_ui/log  \
-p 0.0.0.0:4000:4000 -p 0.0.0.0:5001:5001 \
-e "BINS_TYPE=demo" -e "RELX_REPLACE_OS_VARS=true" \
--name mui -h mui --net=buffy-leader \
docker.sendence.com:5043/sendence/monitoring_hub-apps-metrics_reporter_ui.amd64:sendence-2.3.0-2462-gf6421db
```

#### Restarting UIs

If you need to restart the UI, this can be accomplished by:

```bash
docker stop mui && docker start mui
```

### Running Market Spread

To build Market Spread:

```bash
cd ~/wallaroo
make build-testing-performance-apps-market-spread
```

To build Giles Sender:

```bash
cd ~/wallaroo
make build-giles-sender
```

To build Giles Receiver:

```bash
cd ~/wallaroo
make build-giles-receiver
```

### SINGLE WORKER market spread:

You'll need to have 4 terminals available. 2 for giles senders, 1 for giles receiver, and 1 for the market spread application:

Giles receiver needs to be running before marketspread:

```bash
cd ~/wallaroo
sudo cset proc -s user -e numactl -- -C 14,17 chrt -f 80 ~/wallaroo/giles/receiver/receiver --ponythreads=1 --ponynoblock --ponypinasio -w -l 127.0.0.1:5555
```

```bash
cd ~/wallaroo/testing/performance/apps/market-spread
sudo cset proc -s user -e numactl -- -C 1-8,17 chrt -f 80 ./market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 --ponythreads 8 --ponypinasio --ponynoblock -c 127.0.0.1:12500 -d 127.0.0.1:12501
```

To run the Initial NBBO Sender: (must be started before Orders so that the initial NBBO can be set)

```bash
cd ~/wallaroo
sudo cset proc -s user -e numactl -- -C 15,17 chrt -f 80 ~/wallaroo/giles/sender/sender -h 127.0.0.1:7001 -m 350 -s 300 -i 2_500_000 -f ~/wallaroo/testing/data/market_spread/350-symbols_initial-nbbo-fixish.msg --ponythreads=1 -y -g 46 --ponypinasio -w —ponynoblock
```

To run the NBBO Sender:

```bash
cd ~/wallaroo
sudo cset proc -s user -e numactl -- -C 15,17 chrt -f 80 ~/wallaroo/giles/sender/sender -h 127.0.0.1:7001 -m 10000000000 -s 300 -i 2_500_000 -f ~/wallaroo/testing/data/market_spread/350-symbols_nbbo-fixish.msg -r --ponythreads=1 -y -g 46 --ponypinasio -w —ponynoblock
```

To run the Orders Sender:

```bash
cd ~/wallaroo
sudo cset proc -s user -e numactl -- -C 16,17 chrt -f 80 ~/wallaroo/giles/sender/sender -h 127.0.0.1:7000 -m 5000000000 -s 300 -i 5_000_000 -f ~/wallaroo/testing/data/market_spread/350-symbols_orders-fixish.msg -r --ponythreads=1 -y -g 57 --ponypinasio -w —ponynoblock
```

### Running with System Tap (stap) on Linux

Install stap:

```bash
sudo apt-get install -y systemtap systemtap-runtime systemtap-sdt-dev
```

Get the `dh_actor_telemetry` ponyc branch.

Compile ponyc:

```bash
sudo make install LLVM_CONFIG=~/clang+llvm-3.8.1-x86_64-linux-gnu-ubuntu-16.04/bin/llvm-config use=dtrace
```

Model for running stap (you need to fill in the -c argument as in the example below this one):

```bash
stap ~/ponyc/examples/systemtap/actor-telemetry-heap-only.stp -o stap-out.txt -g --suppress-time-limits -c 'command + args in a string'
```

#### Analyzing output

Get sizes for gc

```bash
grep gc_heapsize telemout.txt | awk -F: '{print $2}' | sort -n| tail
```

Get sizes for alloc

```bash
grep alloc_heapsize telemout.txt | awk -F: '{print $2}' | sort -n | tail
```

Get type_ids. Replace the values with sizes you're looking for.

```bash
egrep '500405056|478746624|2997216|2599456|1185184|135232' -B 4 telemout.txt
```


### Installing a custom Ponyc environment

This is needed if you are going to be making changes to the Pony runtime as
part of tests.

#### Install Clang/LLVM

You should install prebuilt Clang 3.8.1 from the [LLVM download page](http://llvm.org/releases/download.html#3.8.1) under Pre-Built Binaries:

```bash
cd ~/
wget http://llvm.org/releases/3.8.1/clang+llvm-3.8.1-x86_64-linux-gnu-ubuntu-16.04.tar.xz
tar xvf clang+llvm-3.8.1-x86_64-linux-gnu-ubuntu-16.04.tar.xz
export PATH=~/clang+llvm-3.8.1-x86_64-linux-gnu-ubuntu-16.04/bin/:$PATH
echo "export PATH=~/clang+llvm-3.8.1-x86_64-linux-gnu-ubuntu-16.04/bin/:\$PATH" >> ~/.bashrc
```

#### Install Ponyc dependencies

```bash
sudo apt-get update
sudo apt-get install -y build-essential git zlib1g-dev libncurses5-dev libssl-dev
```

#### Install PCRE2

```bash
cd ~/
wget ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre2-10.21.tar.bz2
tar xvf pcre2-10.21.tar.bz2
cd pcre2-10.21
./configure --prefix=/usr
sudo make install
```

#### Install Sendence ponyc

```bash
cd ~/
git clone https://github.com/Sendence/ponyc.git
cd ~/ponyc/
sudo make install LLVM_CONFIG=~/clang+llvm-3.8.1-x86_64-linux-gnu-ubuntu-16.04/bin/llvm-config
```

#### Install pony-stable

```bash
cd ~/
git clone https://github.com/ponylang/pony-stable
cd pony-stable
git checkout 0054b429a54818d187100ed40f5525ec7931b31b;
sudo make install
```

