# Wallaroo Performance Testing Guide

This guide is written to help you get started performance testing Wallaroo. There is an assumption that you have some basic knowledge of Wallaroo and related tooling.

This guide covers general performance testing information. Once you have finished this document you should read the documents for performance tests of either the [Pony](apps/market-spread/PERFORMANCE_TESTING_MARKET_SPREAD.md) or [Python](apps/python/market_spread/PERFORMANCE_TESTING_PYTHON_MARKET_SPREAD.md) APIs.

## Setting up Terraform for AWS Cluster Orchestration

Our performance testing is primarily done on AWS. If you haven't already done so, please have a look at the orchestration/terraform [README](../../orchestration/terraform/README.md), specifically the [Configuration](../../orchestration/terraform/README.md#configuration) section. You should have the list of software installed, including `Terraform 0.7.4`. An AWS Console account is required and you should have the appropriate ssh keys in place.

## Breakdown of Performance Testing Commands

In this section, we'll breakdown some of the commands used for performance testing Wallaroo so you can modify them as needed if you need to run performance tests outside of the setups currently documented.

### AWS Cluster Create Command

A typical command used to create a cluster on AWS for performance testing Wallaroo will have the following format.

```bash
make cluster cluster_name=<YOUR-CLUSTER-NAME> num_followers=2 \
  force_instance=c4.8xlarge ansible_system_cpus=0,18 no_spot=true \
  cluster_project_name=wallaroo_perf_testing ansible_install_devtools=true \
  terraform_args="-var placement_tenancy=dedicated"
```

- `cluster_name`: the name you'd want to use for your cluster, this should be a unique identifier that you can remember.

- `num_followers`: The number of additional instance types to bring up besides the default single instance `wallaroo-leader-1` brought up via the `make cluster` command. If running multi-worker tests, this should be adjusted to include an additional instance per worker. The Metrics UI, Data Receiver(s) and Sender(s) should also be running on a separate instance type where no other Wallaroo worker is running.

- `force_instance`: The instance type you want to use for performance testing. Standard performance testing is done on `c4.8xlarge` instance types. Change this to a different instance type if doing testing that requires a different instance.

- `ansible_system_cpus`: the number of system CPUs to isolate for system processes. c4.8xlarge machines have 36 CPUs in total, we use CPU 0 and it's hyperthread, 18, for system processes. This allows all other CPUs to be isolated for user processes. If using an instacne type other than `c4.8xlarge` you'll want to adjust this to CPU 0 and it's hyperthread for the instance type you're using.

- `no_spot`: This tells AWS to not use spot pricing, this should always be set to `true` to avoid having an instance removed from your cluster during testing.

- `cluster_project_name`: Used to keep track of the projects AWS instances are used for. This should always be `wallaroo_perf_testing ` if you're doing performance testing.

- `ansible_install_devtools`: When set to `true`, preinstalls several tools needed for developing Wallaroo. See the [Dev Tools List](#dev-tools-list) section for a list of tools installed.

- `terraform_args="-var placement_tenancy=dedicated"`: forces the placement tenancy to dedicated for the AWS instances. Needed since there has been an increase in network latency in multi-worker runs.

### Wallaroo Metrics UI Commands

The following command will start the Wallaroo Metrics UI, we're assuming this is being started on `wallaroo-follower-2`:

```bash
docker run -d -u root --cpuset-cpus 0,18 --privileged  -v /usr/bin:/usr/bin:ro \
  -v /var/run/docker.sock:/var/run/docker.sock -v /bin:/bin:ro -v /lib:/lib:ro \
  -v /lib64:/lib64:ro -v /usr:/usr:ro -v /tmp:/apps/metrics_reporter_ui/log \
  -p 0.0.0.0:4000:4000 -p 0.0.0.0:5001:5001 \
  -e "BINS_TYPE=demo" -e "RELX_REPLACE_OS_VARS=true" --name mui -h mui \
  --net=host wallaroo-labs-docker-wallaroolabs.bintray.io/release/metrics_ui:0.5.2
```
To access the Metrics UI, visit the host IP of `wallaroo-follower-2` provided by the output of

### Wallaroo Worker Start Command

Running a Wallaroo worker on AWS will differ from a locally run command because we take advantage of tooling such as `cset`, `numactl`, and `chrt` in order to optimize performance. In this section we'll  breakdown the run commands for a single and 2 worker Wallaroo cluster using the Pony Market Spread application. There is an assumption that you understand the typical arguments used when starting a Wallaroo worker.

#### Single Worker

This command would be run on `wallaroo-leader-1`:

```bash
sudo cset proc -s user -e numactl -- -C 1-16,17 chrt -f 80 \
  ~/wallaroo/testing/performance/apps/market-spread/market-spread \
  -i wallaroo-leader-1:7000,wallaroo-leader-1:7001 -o wallaroo-follower-2:5555 \
  -m wallaroo-follower-2:5001 -c wallaroo-leader-1:12500 \
  -d wallaroo-leader-1:12501 -t -e wallaroo-leader-1:5050 \
  --ponynoblock --ponythreads=16 --ponypinasio --ponypin --ponyminthreads=999
```

- `cset proc -s user -e`: this command tells cset to execute the following commands in the `user` cpuset.

- `numactl -- -C 1-16,17`:  this command tells `numactl` to execute the following command only on the CPUs provided to `-C`. `1-16` is used in this case because we want to use 16 ponythreads. `,17` is used for the Pony ASIO thread because we're using `--ponypinasio`

- `chrt -f 80`: sets the realtime scheduling attributes of the following process to `SCHED_FIFO`

- `-i wallaroo-leader-1:7000,wallaroo-leader-1:7001`: Assuming we're running this command on `wallaroo-leader-1`, this is used in place of the IP that the AWS instance is running on without having to update the command each time it is run on a different AWS cluster.

- `-c wallaroo-leader-1:12500 -d wallaroo-leader-1:12501 -e wallaroo-leader-1:5050`: Assuming we're running this command on `wallaroo-leader-1`, this is used in place of the IP that the AWS instance is running on without having to update the command each time it is run on a different AWS cluster.

- `-o wallaroo-follower-2:5555 -m wallaroo-follower-2:5001`: Assuming we're running the Metrics UI and Data Receiver on  `wallaroo-follower-2`, this is used in place of the IP that the AWS instance is running on without having to update the command each time it is run on a different AWS cluster.

- `--ponythreads=16`: For the current processing rate we currently test Walalroo with, we've determined that 16 threads works best. This should be adjusted to fit the instance type you choose if 16 threads are not avialable.

- `--ponyminthreads=999`: Forces the minimum amount of threads to be used by the application to be the maximum number of CPUs available to the application. This is to remove the possibility of the application using less threads than available.

#### 2 Worker

These commands will only be broken down to reference new additions or changes.

Start `worker 1`, this command would be run on `wallaroo-leader-1`:

```bash
sudo cset proc -s user -e numactl -- -C 1-16,17 chrt -f 80 \
  ~/wallaroo/testing/performance/apps/market-spread/market-spread  \
  -i wallaroo-leader-1:7000,wallaroo-leader-1:7001 -o wallaroo-follower-2:5555 \
  -m wallaroo-follower-2:5001 -c wallaroo-leader-1:12500 -d wallaroo-leader-1:12501 \
  -t -e wallaroo-leader-1:5050  -w 2 --ponynoblock --ponythreads=16 --ponypinasio \
  --ponypin --ponyminthreads=999
```

` -w 2`: This command tells the Wallaroo `Initializer` that it is expecting to start a 2 worker cluster. This should be adjusted to account for the amount of workers you plan to test.

Start `worker 2`, this command would be run on `wallaroo-follower-1`:

```bash
sudo cset proc -s user -e numactl -- -C 1-16,17 chrt -f 80 \
  ~/wallaroo/testing/performance/apps/market-spread/market-spread \
  -i wallaroo-leader-1:7000,wallaroo-leader-1:7001 -o wallaroo-follower-2:5555 \
  -m wallaroo-follower-2:5001 -c wallaroo-leader-1:12500 -n worker2 \
  --ponythreads=16 --ponypinasio --ponypin --ponynoblock --ponyminthreads=999
```

- `-c wallaroo-leader-1:12500`: Control channel used to communicate to the `Initializer`. If the `Initializer` was started on any host other than `wallaroo-leader-1`, this should be adjusted to match that host.

- `-n worker2`: We give the second worker `worker2` as it's name.

### Wallaroo Data Receiver Command

In this section we'll break down the command used to start up Data Receiver to receive data from Wallaroo. It assumes you have basic knowledge of the arguments used to start a receiver.

Starting Data Receiver on `wallaroo-follower-2`:

```bash
sudo cset proc -s user -e numactl -- -C 1,17 chrt -f 80 \
  ~/wallaroo/utils/data_receiver/data_receiver --framed -w -l wallaroo-follower-2:5555 \
  --ponythreads=1 --ponynoblock --ponypinasio --ponypin > received.txt
```

- `numactl -- -C 1,17`: this command tells `numactl` to execute the following command only on the CPUs provided to `-C`. `1` is used in this case because it is the first free CPU available of this instance. `,17` is used for the Pony ASIO thread because we're using `--ponypinasio`.

`-l wallaroo-follower-2:5555`: Assuming we're running on `wallaroo-follower-2` we want to use that as the listening hostname. This should be changed if running on a different host. Port `5555` is used because we're assuming the Wallaroo workers were started with this as the output port. This should be changed if a different port is used when starting the Wallaroo worker(s).

### Wallaroo Data Senders Commands

In this section we'll break down the commands used to start up Giles Senders to send data into Wallaroo. It assumes you have basic knowledge of the arguments used to start a sender.

#### NBBO Senders

We first prime the NBBO pricing with initial NBBO data using the following command on `wallaroo-follower-2`:

```bash
sudo cset proc -s user -e numactl -- -C 2,17 chrt -f 80 \
  ~/wallaroo/giles/sender/sender -h wallaroo-leader-1:7001 -m 350 -s 350 -i 2_500_000 \
  -y -g 46 -w \
  -f ~/wallaroo/testing/data/market_spread/nbbo/350-symbols_initial-nbbo-fixish.msg \
  --ponythreads=1 --ponynoblock --ponypinasio --ponypin
```

- `numactl -- -C 2,17`: this command tells `numactl` to execute the following command only on the CPUs provided to `-C`. `2` is used in this case because we want to use 1 ponythread and we're assuming Data Receiver is on `1`. `,17` is used for the Pony ASIO thread because we're using `--ponypinasio`.

- `-h wallaroo-leader-1:7001`: Assuming the initial Wallaroo worker is running on `wallaroo-leader-1` and expecting NBBO data on port `7001`. This should be updated if the worker is running on a different host or is listening on a different port.

- `-f ~/wallaroo/testing/data/market_spread/nbbo/350-symbols_initial-nbbo-fixish.msg`: Location of initial NBBO data, if you cloned Wallaroo to a different directory update accordingly.

This will run for roughly 1 second and complete. Once done, you may start a repeating sender on `wallaroo-follower-3`:

```bash
sudo cset proc -s user -e numactl -- -C 2,17 chrt -f 80 \
  ~/wallaroo/giles/sender/sender -h wallaroo-leader-1:7001 -m 10000000000 \
  -s 450 -i 2_500_000 -r -y -g 46 -w \
  -f ~/wallaroo/testing/data/market_spread/nbbo/350-symbols_nbbo-fixish.msg \
  --ponythreads=1 --ponypinasio --ponypin --ponynoblock
```
- `numactl -- -C 2,17`: this command tells `numactl` to execute the following command only on the CPUs provided to `-C`. `2` is used in this case because we want to use 1 ponythread and we're assuming Data Receiver is on `1`. `,17` is used for the Pony ASIO thread because we're using `--ponypinasio`. The initial number provided to `numactl` should not clash with a running process started using `numactl`.

`-m 10000000000`: We send in a large amount of total messages to avoid the senders dying on us before testing is complete.

`-s 450`: The batch size we use for NBBO senders. This is currently the upper limit we hit before we see degradation in a single sender when combined with the used interval.

`-i 2_500_000`: The optimal interval rate we've used for sending in NBBO messages.

`-f ~/wallaroo/testing/data/market_spread/nbbo/350-symbols_nbbo-fixish.msg`: Location of NBBO data, if you cloned Wallaroo to a different directory update accordingly.

We currently start 7 NBBO senders for performance testing Pony Market Spread. The initial argument to `numactl -- -C` is incremented from `2` to `8` for each sender we start to avoid collision on CPUs.


#### Orders Senders

Starting a repeating Orders sender on `wallaroo-follower-2`:

```bash
sudo cset proc -s user -e numactl -- -C 9,17 chrt -f 80 ~/wallaroo/giles/sender/sender -h wallaroo-leader-1:7000 -m 5000000000 -s 900 -i 5_000_000 -f ~/wallaroo/testing/data/market_spread/orders/350-symbols_orders-fixish.msg -r --ponythreads=1 -y -g 57 -w --ponypinasio  --ponypin —ponynoblock
```

- `numactl -- -C 9,17`: this command tells `numactl` to execute the following command only on the CPUs provided to `-C`. `9` is used in this case because we want to use 1 ponythread and we're assuming Data Receiver is on `1` and NBBO senders are on `2-8`. `,17` is used for the Pony ASIO thread because we're using `--ponypinasio`. The initial number provided to `numactl` should not clash with a running process started using `numactl`.

`-m 5000000000`: We send in a large amount of total messages to avoid the senders dying on us before testing is complete.

`-s 900`: The batch size we use for Orders senders. This is currently the upper limit we hit before we see degradation in a single sender when combined with the used interval.

`-i 5_000_000`: The optimal interval rate we've used for sending in Orders messages.

`-f ~/wallaroo/testing/data/market_spread/orders/350-symbols_orders-fixish.msg`: Location of Order data, if you cloned Wallaroo to a different directory update accordingly.

We currently start 7 Orders senders for performance testing Pony Market Spread. The initial argument to `numactl -- -C` is incremented from `9` to `15` for each sender we start to avoid collision on CPUs.

### Wallaroo Cluster Shutdown Tool

```bash
sudo cset proc -s user -e numactl -- -C 16,17 chrt -f 80 \
  ~/wallaroo/utils/cluster_shutdown/cluster_shutdown wallaroo-leader-1:5050 \
  --ponythreads=1 --ponynoblock --ponypinasio --ponypin
```

- `wallaroo-leader-1:5050`: We're assuming the initalizer is running on `wallaroo-leader-1` and is using port `5050` for it's external data channel. Update the hostname and/or the port if a different argument is used to start the initial Wallaroo worker.

- `numactl -- -C 16,17`: this command tells `numactl` to execute the following command only on the CPUs provided to `-C`. `16` is used in this case because we want to use 1 ponythread and we're assuming Data Receiver is on `1` and Giles senders are on `2-15`. `,17` is used for the Pony ASIO thread because we're using `--ponypinasio`.

## Information to Record

When running performance tests for Wallaroo, there's certain information we want to capture for all runs:

- **Cluster Create Command**: Allows for reproduction if neccessary.

- **Wallaroo Commands**: Commands used to start Wallaroo workers, Data Receiver, Giles Sender(s), and the Metrics UI.

- **Walalroo Version**: Commit or version used for testing.

- **Ponyc Version**: Commit or version used for testing.

- **Memory Usage**: We want to capture memory usage of each Wallaroo worker running for each test. This information can be optained via `htop`'s `RES` column. Memory for the most part should be stable, if it's growing without bounds this should be documented with a rough estimate of the rate of growth and where the memory was at before shutting down the cluster.

- **Metrics**: Median throughput and latencies should be recorded for each pipeline and each worker. If there appears to be any abnormalities in either, notes should be provided best detailing these abnormalities. Notes can consist of screenshots of the Metrics UI if necessary.

## Custom Installing Ponyc

`ponyc` is installed by default if you used the `ansible_install_devtools=true` command to `/src/ponyc`. If you need to use a different version/commit from mainline ponyc, run the following to uninstall the current version:

```bash
cd /src/ponyc
sudo make uninstall
```

**NOTE:** `sudo` is required for all modifying commands run in the `/src` directory.

## Help Keep This Guide Up to Date

Performance testing Wallaroo is something that will constantly be changing. If there is information missing from this guide or there is a section that needs to be updated, please open an issue or PR. This will make the testing process easier for everyone involved.


## Appendix

### Dev Tools List

- `automake`
- `autotools-dev`
- `build-essential`
- `file`
- `git`
- `libicu-dev`
- `libncurses5-dev`
- `libpcre3`
- `libssl-dev`
- `libxml2-dev`
- `zlib1g-dev`
- `llvm-3.9`
- `libpcre2-dev`
- `libsnappy-dev`
- `liblz4-dev`
- `python-dev`
- `software-properties-common`
- `ponyc`: installs the latest tagged release to `/src/ponyc`
- `pony-stable`: installs the latest tagged release to `/src/pony-stable`
