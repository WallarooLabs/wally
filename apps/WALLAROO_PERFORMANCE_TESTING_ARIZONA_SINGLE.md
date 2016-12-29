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

### Build ponyc
```
cd ~/
git clone https://github.com/Sendence/ponyc.git
cd ~/ponyc/
git checkout export-and-serialize
sudo make install LLVM_CONFIG=~/clang+llvm-3.8.1-x86_64-linux-gnu-ubuntu-16.04/bin/llvm-config
```

### Build spdlog
```
sudo apt-get install cmake
cd
git clone https://github.com/gabime/spdlog.git
cd ~/spdlog
mkdir build
cd build
cmake ..
sudo make install
```

### Build Arizona-CPP
```
cd ~
git clone https://github.com/Sendence/buffy.git
cd buffy
git checkout arizona-add-state
cd lib/wallaroo/cpp-api/cpp/cppapi
mkdir build
cd build
cmake ..
sudo make install
```

### Build giles
```
cd ~/buffy
make build-giles-sender arch=amd64 ponyc_tag=sendence-14.0.5-release
make build-giles-receiver arch=amd64 ponyc_tag=sendence-14.0.5-release
```

### Build Arizona-source-app
```
cd ~/buffy/apps/arizona-source-app
mkdir build
cd build
cmake ..
make
cd ..
ponyc --path=/home/ubuntu/buffy/lib:/usr/local/lib/WallarooCppApi/:/home/ubuntu/buffy/apps/arizona-source-app/build/lib/ --output=build arizona-source-app/
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

### Generate data
Before you can run Arizona, you need to generate data for it with the datagen
app

```
sudo apt-get install pkg-config libconfig++-dev
cd
git clone https://github.com/Sendence/arizona.git
cd ~/arizona
git checkout state-node-compute
mkdir build
cd build
cmake ..
make
cd ~/arizona/bin_cfggen/etc
../../build/bin_cfggen/bin/datagen -c test_source_app.cfg
```
this will create ~/arizona/bin_cfggen/etc/test-source-100k.dat and the four
"separate message types" files, if those are what you need to test a specific
order type. You can even `cat` them together if you need combinations (e.g.
orders + cancels) - they just won't be interleaved.

### Running Arizona

You'll need to have 3 terminals available. 1 for giles sender, 1 for giles receiver, and 1 for the application:

Giles receiver needs to be running before arizona:
```
sudo cset proc -s user -e numactl -- -C 14 chrt -f 80 ~/buffy/giles/receiver/receiver --ponythreads=1 --ponynoblock -w -l 127.0.0.1:5555
```

```
cd ~/buffy/apps/arizona-source-app
sudo cset proc -s user -e numactl -- -C 1-12,17 chrt -f 80 ./build/arizona-source-app -i 127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 --ponythreads 12 --ponypinasio --ponynoblock -c 127.0.0.1:12500 -d 127.0.0.1:12501
```

To run the Orders Sender:
```
sudo cset proc -s user -e numactl -- -C 15,17 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7001 -m 10000000000 -s 300 -i 2_500_000 -f ~/arizona/bin_cfggen/etc/test-source-100k.dat -r --ponythreads=1 -y -z --ponypinasio -w —ponynoblock
```
