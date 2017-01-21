# Building and Testing `Arizona` -- RedHat

If you have not followed the setup instructions in the orchestration/terraform [README](https://github.com/Sendence/buffy/tree/master/orchestration/terraform) please do so before continuing.

## Arizona Cluster
**Please note:** WHEN DOING MULTIPLE MACHINE TESTS YOU HAVE TO USE TERRAFORM FOLLOWERS VALUE.  If you spin up individual machines, they won’t end up in the same placement group and then not good performance.

### Configuring Cluster:

Before configuring your cluster, make sure you are in
your `orchestration/arizona` directory.

Create a cluster by running (NOTE: These instances are faster than what the bank has provided us. If you're testing for a "bank equivalent" environment, change `c4.8xlarge` to `r3.4xlarge` and `0,18` to `0,8`):
```
make cluster cluster_name=###REPLACE_ME### num_followers=###NUM_FOLLOWERS## force_instance=c4.8xlarge arizona_node_type=development ansible_system_cpus=0,18
```

You'll get a response ending with something similar to this if successful:
```bash
PLAY RECAP *********************************************************************
54.165.9.39                : ok=70   changed=39   unreachable=0    failed=0
```

You can SSH into the machine using:

```bash
ssh -i ~/.ssh/ec2/us-east-1.pem ec2-user@<IP_ADDRESS>
```

## Generate data
Before you can run Arizona, you need to generate data for it with the datagen app. This can take some time (depending on how large of a dataset you are building), so do this step first.

As for how long it will take to generate your data, a good rule of thumb is to halve the time you want to generate. So, if you want to generate 20 mins of data, it will take 10 mins to do. If you want to do 1 hour, it will take 30 mins... etc.
### Building data generation tools
Please note - you only have to run the `scl` command once. If you are copying these instructions into a script, do **NOT** include that. Run it from the command  line and then your script.
#### Build spdlog
```
scl enable devtoolset-4 bash
cd ~/
git clone https://github.com/gabime/spdlog.git
cd ~/spdlog
mkdir build
cd build
cmake ..
sudo make install
```

#### Build Arizona-CPP
```
scl enable devtoolset-4 bash
git clone https://github.com/Sendence/buffy.git

cd ~/buffy
cd lib/wallaroo/cpp-api/cpp/cppapi
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
sudo make install
```

#### The Arizona Ancillary Tools (AZAT)
```
scl enable devtoolset-4 bash
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
sudo mkdir -p /apps/dev/arizona/data
sudo chown -R ec2-user:ec2-user /apps/dev/arizona
cd ~/arizona/bin_cfggen/etc
cp *.cfg /apps/dev/arizona/etc/
```

### Actual data generation
Your options are:
#### Create a really small file (150K message) that you can loop through, should not have memory growth

```
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
cd /apps/dev/arizona/data
/apps/dev/arizona/bin/arizona/pairgen -c /apps/dev/arizona/etc/pairgen_1375_1M_admin.cfg
```
* Your data files will appear in your current directory, suggested: /apps/dev/arizona/data
* Data files: azdata_pairgen_loop_1375_1M_admin.dat[*]
* Each order needs a correspoding cancel or execute message. Use the `full` file for loops.



#### Create a 15 minute data set (do we crash?)

```
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
cd /apps/dev/arizona/data
/apps/dev/arizona/bin/arizona/datagen -c /apps/dev/arizona/etc/data_15min.cfg
```
* Do not use the files for looping.
* Your data files will appear in your current directory, suggested: /apps/dev/arizona/data
* Data files: azdata_15mins_noloop.dat[*]
* Use the `full` for messages of multiple types(orders,cancels,executes)


#### Create a 60 minute data set (are there long-term problems?)

```
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
cd /apps/dev/arizona/data
/apps/dev/arizona/bin/arizona/datagen -c /apps/dev/arizona/etc/data_1hour.cfg
```
* Do not use the files for looping
* Your data files will appear in your current directory, suggested: /apps/dev/arizona/data
* Data files: azdata_1hr_noloop.dat[*]
* Use the `full` for messages of multiple types(orders,cancels,executes)

#### Create an 8 hour data set (does this work for the full 8 hours?)


```
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
cd /apps/dev/arizona/data
/apps/dev/arizona/bin/arizona/datagen -c /apps/dev/arizona/etc/data_8hours.cfg
```

* Do not use the files for looping
* Your data files will appear in your current directory, suggested: /apps/dev/arizona/data
* Data files:  azdata_8hrs_noloop.dat[*]
* Use the `full` for messages of multiple types(orders,cancels,executes)

## Arizona/Wallaroo
### Clone Wallaroo repo

You'll need to clone the repo if you don't have it already:
```
cd ~/
git clone https://github.com/sendence/buffy.git
```

### Verify optimal setup

```bash
~/buffy/scratch/misc/validate_environment.sh
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

### Build ponyc
```
cd ~/
git clone https://github.com/Sendence/ponyc.git
cd ~/ponyc/
```
```
<manually edit Makefile for>
llvm.libs := $(shell $(LLVM_CONFIG) --libs) -lz -lncurses
to
llvm.libs := $(shell $(LLVM_CONFIG) --libs) -lz -lncurses -ltinfo
(append ' -ltinfo')

symlink.flags = -srf
to
symlink.flags = -sf
```

```
scl enable devtoolset-4 python27 "LTO_PLUGIN=/opt/rh/devtoolset-4/root/usr/libexec/gcc/x86_64-redhat-linux/5.3.1/liblto_plugin.so make prefix=/usr/local verbose=1 -j`nproc` test"

scl enable devtoolset-4 python27 "LTO_PLUGIN=/opt/rh/devtoolset-4/root/usr/libexec/gcc/x86_64-redhat-linux/5.3.1/liblto_plugin.so sudo make prefix=/usr/local verbose=1 install"

cd ..
```

### Install pony stable
```
cd ~/
git clone https://github.com/jemc/pony-stable.git
cd pony-stable/
scl enable devtoolset-4 python27 "make"
scl enable devtoolset-4 python27 "sudo make install"
```


### Build giles sender
```
cd ~/buffy/giles/sender
scl enable devtoolset-4 python27 "stable env ponyc"
```

### Build giles receiver
**Note:**You must use sendence ponyc version: sendence-17.0.4 or greater
```
cd ~/buffy/giles/receiver
scl enable devtoolset-4 python27 "stable env ponyc"
```

### Build Arizona-source-app
```
cd ~/buffy/apps/arizona-source-app
mkdir build
cd build
scl enable devtoolset-4 python27  "cmake .."
scl enable devtoolset-4 python27  "make"
cd ..
scl enable devtoolset-4 python27  "ponyc --path=/home/ec2-user/buffy/lib:/usr/local/lib/WallarooCppApi/:/home/ec2-user/buffy/apps/arizona-source-app/build/lib/ --output=build arizona-source-app/"
```

### Startup the Metrics UI

You need to download and untar the Metrics UI with the following commands:
```bash
cd ~/
mkdir metrics_reporter_ui
cd metrics_reporter_ui
wget https://s3.amazonaws.com/sendence-dev/wallaroo/metrics_reporter_ui-bins/linux/metrics_reporter_ui-new-rhel.tar.gz
tar -xvf metrics_reporter_ui-new-rhel.tar.gz -C ~/metrics_reporter_ui/
```

To run the Metrics UI:
```bash
cd ~/metrics_reporter_ui
./bin/metrics_reporter_ui start
```

#### Restarting UIs

If you need to restart the UI, this can be accomplished by:

```bash
cd ~/metrics_reporter_ui
./bin/metrics_reporter_ui restart
```



### Running Arizona

You'll need to have 3 terminals available. 1 for giles sender, 1 for giles receiver, and 1 for the application:

#### Running the Receiver

Giles receiver needs to be running before arizona:
```
cd ~/buffy
sudo cset proc -s user -e numactl -- -C 6,7 chrt -f 80 ~/buffy/giles/receiver/receiver --ponythreads=1 --ponynoblock --ponypinasio -w -l 127.0.0.1:5555
```

#### Running the application

```
cd ~/buffy/apps/arizona-source-app
sudo cset proc -s user -e numactl -- -C 1-4,7 chrt -f 80 ./build/arizona-source-app -i 127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 --ponythreads 4 --ponypinasio --ponynoblock -c 127.0.0.1:12500 -d 127.0.0.1:12501 --clients=1375
```

#### Running the Sender

To run the Orders Sender:

##### With Looping (for the pairgen'd file)

```
cd ~/buffy
sudo cset proc -s user -e numactl -- -C 5,7 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7001 -m 10000000000 -s 300 -i 2_500_000 -f ~/arizona/bin_cfggen/etc/test-source-looping.dat.full -r --ponythreads=1 -y -z --ponypinasio -w —ponynoblock
```

##### For the 15 minute run

```
cd ~/buffy
sudo cset proc -s user -e numactl -- -C 5,7 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7001 -m 10000000000 -s 300 -i 2_500_000 -f ~/arizona/bin_cfggen/etc/test-source-15-minute.dat.full --ponythreads=1 -y -z --ponypinasio -w —ponynoblock
```

##### For the 60 minute run

```
cd ~/buffy
sudo cset proc -s user -e numactl -- -C 5,7 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7001 -m 10000000000 -s 300 -i 2_500_000 -f ~/arizona/bin_cfggen/etc/test-source-60-minute.dat.full --ponythreads=1 -y -z --ponypinasio -w —ponynoblock
```

##### For the 8 hour run

```
cd ~/buffy
sudo cset proc -s user -e numactl -- -C 5,7 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7001 -m 10000000000 -s 300 -i 2_500_000 -f ~/arizona/bin_cfggen/etc/test-source-8-hour.dat.full --ponythreads=1 -y -z --ponypinasio -w —ponynoblock
```

#### 2 MACHINES/2 WORKERS
Make sure you have the same binary on both machines or you'll get segfaults with serialization. Compile the binary on Machine 1 and use `scp` to copy to the other machine:

`scp -i ~/.ssh/us-east-1.pem arizona-binary ec2-user@<TARGET-MACHINE-IP>:~/path/to/copy/to`

On each machine, run Giles receiver before arizona:
```
cd ~/buffy
sudo cset proc -s user -e numactl -- -C 6,7 chrt -f 80 ~/buffy/giles/receiver/receiver --ponythreads=1 --ponynoblock --ponypinasio -w -l 127.0.0.1:5555
```

Run Arizona on Machine 1:
```
sudo cset proc -s user -e numactl -- -C 1-4,7 chrt -f 80 ./build/arizona-source-app -i 0.0.0.0:7000,0.0.0.0:7001 -o <MACHINE IP ADDRESS FOR OUTPUT>:5555 -m <MACHINE IP ADDRESS FOR METRICS>:5001 -c 0.0.0.0:12500 -d 0.0.0.0:12501 --ponythreads 4 --ponypinasio --ponynoblock -w 2 --clients=5500
```

Run Arizona on Machine 2:
```
sudo cset proc -s user -e numactl -- -C 1-4,17 chrt -f 80 ./arizona-source-app -i 0.0.0.0:7000,0.0.0.0:7001 -o <MACHINE IP ADDRESS FOR OUTPUT>:5555 -m <MACHINE IP ADDRESS FOR METRICS>:5001 -c <INITIALIZER>:12500 -d <INITIALIZER>:12501 --ponythreads 4 --ponypinasio --ponynoblock -n worker2 -w 2 --clients=5500
```

Orders Sender on Machine 1:
Follow instructions in 1 MACHINE run section
