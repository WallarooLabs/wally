# Arizona Single Machine Performance Testing on AWS

If you have not followed the setup instructions in the orchestration/terraform [README](https://github.com/Sendence/buffy/tree/master/orchestration/terraform) please do so before continuing.

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
git clone https://github.com/sendence/buffy.git
```

### Verify optimal setup

```bash
~/buffy/scratch/misc/validate_environment.sh
```

You should see:

```bash
Network driver is set up correctly for optimal performance.
System cpu isolation set up as expected for optimal performance.
System clocksource is set up correctly for optimal performance.
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
docker.sendence.com:5043/wallaroo-metrics-ui-new:latest
```

#### Restarting UIs

If you need to restart the UI, this can be accomplished by:

```bash
docker stop mui && docker start mui
```

### Running Market Spread

To build Market Spread:
```
cd ~/buffy
make arch=amd64 build-apps-market-spread
```

To build Giles Sender:
```
cd ~/buffy
make build-giles-sender arch=amd64 ponyc_tag=sendence-14.0.5-release
```

To build Giles Receiver:
```
cd ~/buffy
make build-giles-receiver arch=amd64 ponyc_tag=sendence-14.0.5-release
```

### SINGLE WORKER market spread:

You'll need to have 4 terminals available. 2 for giles senders, 1 for giles receiver, and 1 for the market spread application:

Giles receiver needs to be running before marketspread:
```
cd ~/buffy
sudo cset proc -s user -e numactl -- -C 14 chrt -f 80 ~/buffy/giles/receiver/receiver --ponythreads=1 --ponynoblock -w -l 127.0.0.1:5555
```

```
cd ~/buffy/apps/market-spread
sudo cset proc -s user -e numactl -- -C 1-12,17 chrt -f 80 ./market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 --ponythreads 12 --ponypinasio --ponynoblock -c 127.0.0.1:12500 -d 127.0.0.1:12501
```

To run the NBBO Sender: (must be started before Orders so that the initial NBBO can be set)
```
cd ~/buffy
sudo cset proc -s user -e numactl -- -C 15,17 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7001 -m 10000000000 -s 300 -i 2_500_000 -f ~/buffy/demos/marketspread/350k-nbbo-fixish.msg -r --ponythreads=1 -y -g 46 --ponypinasio -w —ponynoblock
```

To run the Orders Sender:
```
cd ~/buffy
sudo cset proc -s user -e numactl -- -C 16,17 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7000 -m 5000000000 -s 300 -i 5_000_000 -f ~/buffy/demos/marketspread/350k-orders-fixish.msg -r --ponythreads=1 -y -g 57 --ponypinasio -w —ponynoblock
```

### Running with System Tap (stap) on Linux

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

### Running 2 worker market spread:
```
sudo cset proc -s user -e numactl -- -C 1-12,17 chrt -f 80 ~/buffy/apps/market-spread/market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:12500 -d 127.0.0.1:12501 -f ../../demos/marketspread/r3k-initial-nbbo-fixish.msg -s ../../demos/marketspread/r3k-legal-symbols.msg --ponythreads 12 --ponypinasio --ponynoblock -t -w 2

sudo cset proc -s user -e numactl -- -C 1-12,17 chrt -f 80 ~/buffy/apps/market-spread/market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:12500 -d 127.0.0.1:12501 -f ../../demos/marketspread/r3k-initial-nbbo-fixish.msg -s ../../demos/marketspread/r3k-legal-symbols.msg --ponythreads 12 --ponypinasio --ponynoblock -w 2
```

### Running 2 MACHINE/ 2 worker market spread:
Giles receiver needs to be running before marketspread (can be on either machine, but for consistency put it on
machine 2):
```
cd ~/buffy
sudo cset proc -s user -e numactl -- -C 14 chrt -f 80 ~/buffy/giles/receiver/receiver --ponythreads=1 --ponynoblock -w -l 0.0.0.0:5555
```

Machine 1:
```
sudo cset proc -s user -e numactl -- -C 1-12,17 chrt -f 80 ~/buffy/apps/market-spread/market-spread -i 0.0.0.0:7000,0.0.0.0:7001 -o <MACHINE IP ADDRESS FOR OUTPUT>:5555 -m <MACHINE IP ADDRESS FOR METRICS>:5001 -c 0.0.0.0:12500 -d 0.0.0.0:12501 --ponythreads 12 --ponypinasio --ponynoblock -t -w 2
```

Machine 2:
```
sudo cset proc -s user -e numactl -- -C 1-12,17 chrt -f 80 ~/buffy/apps/market-spread/market-spread -i 0.0.0.0:7000,0.0.0.0:7001 -o <MACHINE IP ADDRESS FOR OUTPUT>:5555 -m <MACHINE IP ADDRESS FOR METRICS>:5001 -c 0.0.0.0:12500 -d 0.0.0.0:12501 --ponythreads 12 --ponypinasio --ponynoblock -n worker2 -w 2
```

### Installing a custom Ponyc environment

This is needed if you are going to be making changes to the Pony runtime as
part of tests.

#### Install Clang/LLVM

You should install prebuilt Clang 3.8 from the [LLVM download page](http://llvm.org/releases/download.html#3.8.0) under Pre-Built Binaries:

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
git clone https://github.com/jemc/pony-stable.git
cd pony-stable
sudo make install
```

