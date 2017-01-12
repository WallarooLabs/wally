# Arizona Single Machine Performance Testing on AWS

If you have not followed the setup instructions in the orchestration/terraform [README](https://github.com/Sendence/buffy/tree/master/orchestration/terraform) please do so before continuing.

## Configuring Cluster:

Before configuring your cluster, make sure you are in
your `orchestration/arizona` directory.

Arizona has two different kinds of machiens, build and execution.      
**This document assumes you build all binaries on a build machine and then copy them onto the execution machines.**
We already have a build machine, called ***arizona-build-server*** you can log in to that host with:
```
ssh -i YOUR_PEM_FILE ec2-user@AWS-HOST-NAME
```

Or, you can create a build machine, by running:
```
make cluster cluster_name=<CLUSTER_NAME> num_followers=0 force_instance=r3.4xlarge arizona_node_type=build ansible_system_cpus=0,8
```

To create execution machines, use:
```bash
make cluster cluster_name=###REPLACE_ME### num_followers=###NUM_FOLLOWERS##
```

You'll get a response ending with something similar to this if successful:
```bash
PLAY RECAP *********************************************************************
54.165.9.39                : ok=70   changed=39   unreachable=0    failed=0
```

You can SSH into the build machine using:

```bash
ssh -i ~/.ssh/ec2/us-east-1.pem ec2-user@<IP_ADDRESS>
```

## Generate data
Before you can run Arizona, you need to generate data for it with the datagen app. This can take some time (depending on how large of a dataset you are building), so do this step first.

As for how long it will take to generate your data, a good rule of thumb is to halve the time you want to generate. So, if you want to generate 20 mins of data, it will take 10 mins to do. If you want to do 1 hour, it will take 30 mins... etc.

#### Build libconfig
**Please note:** this is only needed on the machines where datagen, pairgen, etc. will be run.
```
wget http://libconfig.sourcearchive.com/downloads/1.5-0.2/libconfig_1.5.orig.tar.gz
tar zxvf libconfig_1.5.orig.tar.gz
cd libconfig-1.5
./configure
make
sudo make install
```

#### Build spdlog
**Note:**You don't have to do this if you are using the arizona-build-server
```
scl enable devtoolset-4 bash //only for redhat executuon machines
cd ~/
git clone https://github.com/gabime/spdlog.git
cd ~/spdlog
mkdir build
cd build
cmake ..
sudo make install
```

#### Build Arizona-CPP
**Note:**You don't have to do this if you are using the arizona-build-server
```
scl enable devtoolset-4 bash //only for redhat executuon machines
cd ~/buffy
git checkout arizona-add-state
cd lib/wallaroo/cpp-api/cpp/cppapi
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
sudo make install
```

#### The Arizona Ancillary Tools (AZAT)
```
scl enable devtoolset-4 bash //only for redhat executuon machines
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:PKG_CONFIG_PATH
cd ~/
git clone https://github.com/Sendence/arizona.git
cd ~/arizona
git checkout state-node-compute
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/apps/dev/arizona ../
sudo make install
sudo mkdir /apps/dev/arizona/etc
cd ~/arizona/bin_cfggen/etc
cp *.cfg /apps/dev/arizona/etc/
scp -i YOUR_PEM_FILE -r /apps/dev/arizona ec2-user@EXECUTION_HOST_IP:/apps/dev/arizona
```

At this point, you will be ready to generate data. Log into the executon host that you copied your files to. The options are:

#### Create a really small file (150K message) that you can loop through, should not have memory growth

```
ssh -i YOUR_PEM ec2-user@YOUR-EXECUTION-SERVER-IP
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
mkdir -p /apps/dev/arizona/data
/apps/dev/arizona/bin/arizona/pairgen -c /apps/dev/arizona/etc/pairgen_150K.cfg
```
* Your data files will appear in: /apps/dev/arizona/pairgen_150K.dat[*]
* Each order needs a correspoding cancel or execute message. Use the `full` file for loops.



#### Create a 15 minute data set (do we crash?)

```
ssh -i YOUR_PEM ec2-user@YOUR-EXECUTION-SERVER-IP
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
mkdir -p /apps/dev/arizona/data
/apps/dev/arizona/bin/arizona/datagen-c data_15min.cfg
```
* Do not use the files for looping.
* Your data files will appear in: /apps/dev/arizona/data/azdata_15mins.dat[*]
* Use the `full` for messages of multiple types(orders,cancels,executes)


#### Create a 60 minute data set (are there long-term problems?)

```
ssh -i YOUR_PEM ec2-user@YOUR-EXECUTION-SERVER-IP
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
mkdir -p /apps/dev/arizona/data
/apps/dev/arizona/bin/datagen -c data_1hour.cfg
```
* Do not use the files for looping
* Your data files will appear in: /apps/dev/arizona/data/azdata_1hour.dat
* Use the `full` for messages of multiple types(orders,cancels,executes)

#### Create an 8 hour data set (does this work for the full 8 hours?)


```
ssh -i YOUR_PEM ec2-user@YOUR-EXECUTION-SERVER-IP
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
mkdir -p /apps/dev/arizona/data
/apps/dev/arizona/bin/datagen -c data_8hours.cfg
```

* Do not use the files for looping
* Your data files will appear in: /apps/dev/arizona/data/azdata_8hrs.dat
* Use the `full` for messages of multiple types(orders,cancels,executes)


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



### Running Arizona

You'll need to have 3 terminals available. 1 for giles sender, 1 for giles receiver, and 1 for the application:

#### Running the Receiver

Giles receiver needs to be running before arizona:
```
cd ~/buffy
sudo cset proc -s user -e numactl -- -C 14,17 chrt -f 80 ~/buffy/giles/receiver/receiver --ponythreads=1 --ponynoblock --ponypinasio -w -l 127.0.0.1:5555 -t
```

#### Running the application

```
cd ~/buffy/apps/arizona-source-app
sudo cset proc -s user -e numactl -- -C 1-4,17 chrt -f 80 ./build/arizona-source-app -i 127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 --ponythreads 4 --ponypinasio --ponynoblock -c 127.0.0.1:12500 -d 127.0.0.1:12501 --clients=5500
```

#### Running the Sender

To run the Orders Sender:

##### With Looping (for the pairgen'd file)

```
cd ~/buffy
sudo cset proc -s user -e numactl -- -C 15,17 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7001 -m 10000000000 -s 300 -i 2_500_000 -f ~/arizona/bin_cfggen/etc/test-source-looping.dat.full -r --ponythreads=1 -y -z --ponypinasio -w —ponynoblock
```

##### For the 15 minute run

```
cd ~/buffy
sudo cset proc -s user -e numactl -- -C 15,17 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7001 -m 10000000000 -s 300 -i 2_500_000 -f ~/arizona/bin_cfggen/etc/test-source-15-minute.dat.full --ponythreads=1 -y -z --ponypinasio -w —ponynoblock
```

##### For the 60 minute run

```
cd ~/buffy
sudo cset proc -s user -e numactl -- -C 15,17 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7001 -m 10000000000 -s 300 -i 2_500_000 -f ~/arizona/bin_cfggen/etc/test-source-60-minute.dat.full --ponythreads=1 -y -z --ponypinasio -w —ponynoblock
```

##### For the 8 hour run

```
cd ~/buffy
sudo cset proc -s user -e numactl -- -C 15,17 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7001 -m 10000000000 -s 300 -i 2_500_000 -f ~/arizona/bin_cfggen/etc/test-source-8-hour.dat.full --ponythreads=1 -y -z --ponypinasio -w —ponynoblock
```

#### 2 MACHINES/2 WORKERS
Make sure you have the same binary on both machines or you'll get segfaults with serialization. Compile the binary on Machine 1 and use `scp` to copy to the other machine:

`scp -i ~/.ssh/us-east-1.pem arizona-binary ubuntu@<TARGET-MACHINE-IP>:~/path/to/copy/to`

On each machine, run Giles receiver before arizona:
```
cd ~/buffy
sudo cset proc -s user -e numactl -- -C 14,17 chrt -f 80 ~/buffy/giles/receiver/receiver --ponythreads=1 --ponynoblock --ponypinasio -w -l 127.0.0.1:5555 -t
```

Run Arizona on Machine 1:
```
sudo cset proc -s user -e numactl -- -C 1-4,17 chrt -f 80 ./build/arizona-source-app -i 0.0.0.0:7000,0.0.0.0:7001 -o <MACHINE IP ADDRESS FOR OUTPUT>:5555 -m <MACHINE IP ADDRESS FOR METRICS>:5001 -c 0.0.0.0:12500 -d 0.0.0.0:12501 --ponythreads 4 --ponypinasio --ponynoblock -t -w 2 --clients=5500
```

Run Arizona on Machine 2:
```
sudo cset proc -s user -e numactl -- -C 1-4,17 chrt -f 80 ./arizona-source-app -i 0.0.0.0:7000,0.0.0.0:7001 -o <MACHINE IP ADDRESS FOR OUTPUT>:5555 -m <MACHINE IP ADDRESS FOR METRICS>:5001 -c <INITIALIZER>:12500 -d <INITIALIZER>:12501 --ponythreads 4 --ponypinasio --ponynoblock -n worker2 -w 2 --clients=5500
```

Orders Sender on Machine 1:
Follow instructions in 1 MACHINE run section
