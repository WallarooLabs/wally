# Performance Testing Python Market Spread Guide

This is a guide for starting up an AWS cluster and running Wallaroo's Performance Testing using Python Market Spread for both [single worker](#single-worker-pony-market-spread) and [two worker](#two-worker-pony-market-spread).

If you have not read the [WALLAROO PERFORMANCE TESTING GUIDE](../../../WALLAROO_PERFORMANCE_TESTING_GUIDE.md) it is recommended that you do so before continuing.

## Cluster Start

To start an AWS cluster first change directories from within the main `wallaroo` directory with the following command:

```bash
cd orchestration/terraform
```

You will have to replace `<YOUR-CLUSTER-NAME>` with the name you want to give your cluster in the command below. We will be starting a 3 machine cluster `wallaroo-leader-1` for the initial Market Spread Wallaroo worker, `wallaroo-follower-1` for the NBBO/Orders senders, and `wallaroo-follower-2` for Giles Receiver and the Metrics UI. You can increase the number provided to `num_followers` for each additional Wallaroo worker you plan to test if testing more than a single worker.

The following command will spin up the cluster:

```bash
make cluster cluster_name=<YOUR-CLUSTER-NAME> num_followers=2 force_instance=c4.8xlarge ansible_system_cpus=0,18 no_spot=true cluster_project_name=wallaroo_perf_testing ansible_install_devtools=true terraform_args="-var placement_tenancy=dedicated"
```

If successful, you should see output that looks like this:

**NOTE**: The IPs will differ each time you spin up a cluster, the below is just an example and the IP values should not be used to ssh into an AWS instance.

```bash
PLAY RECAP *********************************************************************
52.3.244.174               : ok=86   changed=54   unreachable=0    failed=0
54.172.117.178             : ok=86   changed=54   unreachable=0    failed=0
54.174.246.168             : ok=87   changed=54   unreachable=0    failed=0

==> Successfully ran ansible playbook for cluster 'perftest' in region 'us-east-1' at provider 'aws'!
```

### Obtaining Hostnames from AWS Instances

In order to obtain the hostnames for each of the AWS instances you started, you will run the following command with the same exact arguments you used to start the cluster with `make cluster ...` but replacing `cluster` with `test-ansible-connection`.

```bash
make test-ansible-connection cluster_name=<YOUR-CLUSTER-NAME> num_followers=2 force_instance=c4.8xlarge ansible_system_cpus=0,18 no_spot=true cluster_project_name=wallaroo_perf_testing ansible_install_devtools=true
```
The output of that command should look similar to this:

```bash
==> Running ansible connectivity/authentication check for cluster 'perftest' in region 'us-east-1' at provider 'aws'...
PACKET_NET_API_KEY= ansible 'tag_Project_wallaroo_perf_testing:&tag_ClusterName_perftest:&us-east-1' \
          -i ../ansible/ec2.py --ssh-common-args="-o StrictHostKeyChecking=no \
          -i  /Users/jonbrwn/.ssh/ec2/us-east-1.pem"  -u ubuntu -m raw -a "hostname -A"
52.3.244.174 | SUCCESS | rc=0 >>
wallaroo-follower-2 ip-172-17-0-1.ec2.internal


54.172.117.178 | SUCCESS | rc=0 >>
wallaroo-leader-1 ip-172-17-0-1.ec2.internal


54.174.246.168 | SUCCESS | rc=0 >>
wallaroo-follower-1 ip-172-17-0-1.ec2.internal


==> Successfully ran ansible connectivity/authentication check for cluster 'perftest' in region 'us-east-1' at provider 'aws'...
```

You can SSH into the AWS machines using the following command, where `<IP_ADDRESS>` is replaced by one of the IP addresses provided by the output of the command above.

```bash
ssh -i ~/.ssh/ec2/us-east-1.pem ubuntu@<IP_ADDRESS>
```

So if we wanted to ssh into `wallaroo-leader-1`, we'd use the IP `54.172.117.178` based on this output:

```bash
54.172.117.178 | SUCCESS | rc=0 >>
wallaroo-leader-1 ip-172-17-0-1.ec2.internal
```

Like so:

```bash
ssh -i ~/.ssh/ec2/us-east-1.pem ubuntu@54.172.117.178
```

## Clone Wallaroo onto wallaroo-leader-1

SSH into the `wallaroo-leader-1` machine and get a copy of the `wallaroo` repo:

```bash
cd ~/
git clone https://github.com/WallarooLabs/wallaroo.git
```

## Single Worker Pony Market Spread

### Building Wallaroo and Tooling

ssh into `wallaroo-leader-1`.

Build the required Wallaroo tools:

```bash
cd ~/wallaroo
make build-machida build-giles-all build-utils-cluster_shutdown
```

`scp` Wallaroo to other workers on the cluster:

```bash
scp -r -o StrictHostKeyChecking=no ~/wallaroo/ ubuntu@wallaroo-follower-1:~/wallaroo
scp -r -o StrictHostKeyChecking=no ~/wallaroo/ ubuntu@wallaroo-follower-2:~/wallaroo
```

### Validate Testing Environment

A script is provided to verify that the testing environment is in an optimal state for testing. To run this script, ssh into each instance and run the following:

```bash
~/wallaroo/orchestration/validate_environment.sh
```

This is the expected output:

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

### Start Metrics UI

SSH into `wallaroo-follower-2`

Start the Metrics UI:

```bash
docker run -d -u root --cpuset-cpus 10-18 --privileged  -v /usr/bin:/usr/bin:ro   -v /var/run/docker.sock:/var/run/docker.sock -v /bin:/bin:ro  -v /lib:/lib:ro  -v /lib64:/lib64:ro  -v /usr:/usr:ro  -v /tmp:/apps/metrics_reporter_ui/log  -p 0.0.0.0:4000:4000 -p 0.0.0.0:5001:5001 --name mui -h mui --net=host wallaroo-labs-docker-wallaroolabs.bintray.io/release/metrics_ui:0.5.2
```

You can verify the Metrics UI is up by visiting the IP address of `wallaroo-follower-2` with `:4000` appended. So if the IP was `54.172.117.178` you'd visit https://54.172.117.178:4000

##### Restarting the Metrics UI

If you need to restart the Metrics UI, run the following command on the machine you started the Metrics UI on:

```bash
docker restart mui
```

### Running Single Worker Python Market Spread

#### Start Giles Receiver

SSH into `wallaroo-follower-2`

Start Giles Receiver with the following command:

```bash
sudo cset proc -s user -e numactl -- -C 1,17 chrt -f 80 ~/wallaroo/giles/receiver/receiver --ponythreads=1 --ponynoblock --ponypinasio -w -l wallaroo-follower-2:5555
```

### Start the Python Market Spread Application

SSH into `wallaroo-leader-1`

Start the Python Market Spread application with the following command:

```bash
cd ~/wallaroo/testing/performance/apps/python/market_spread

sudo PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo/machida" cset proc -s user -e numactl -- -C 1,17 chrt -f 80 ~/wallaroo/machida/build/machida --application-module market_spread -i wallaroo-leader-1:7000,wallaroo-leader-1:7001 -o wallaroo-follower-2:5555 -m wallaroo-follower-2:5001 -c wallaroo-leader-1:12500 -d wallaroo-leader-1:12501 -t -e wallaroo-leader-1:5050 --ponythreads=1 --ponypinasio --ponynoblock
```

### Start Giles Senders

These senders send out roughly 45k messages per second per stream, this is the current baseline for maximum performance of Python Market Spread, depending what you are testing this may need to be adjusted. Please visit the "Wallaroo Data Senders Commands" section of the [WALLAROO PERFORMANCE TESTING GUIDE](../../WALLAROO_PERFORMANCE_TESTING_GUIDE.md#wallaroo-data-senders-commands) for more information regarding adjusting these values.

SSH into `wallaroo-follower-1`

You can run the following commands individually or in a script, the only sender that must be run to completion before starting any of the others is the Initial NBBO Sender.

##### Initial NBBO Sender

```bash
sudo cset proc -s user -e numactl -- -C 1,17 chrt -f 80 ~/wallaroo/giles/sender/sender -h wallaroo-leader-1:7001 -m 350 -s 90 -i 2_500_000 -f ~/wallaroo/testing/data/market_spread/nbbo/350-symbols_initial-nbbo-fixish.msg --ponythreads=1 -y -g 46 --ponypinasio -w --ponynoblock
```

#### NBBO Sender

```bash
sudo cset proc -s user -e numactl -- -C 2,17 chrt -f 80 ~/wallaroo/giles/sender/sender -h wallaroo-leader-1:7001 -m 10000000000 -s 100 -i 2_500_000 -f ~/wallaroo/testing/data/market_spread/nbbo/350-symbols_nbbo-fixish.msg -r --ponythreads=1 -y -g 46 --ponypinasio -w --ponynoblock
```

#### Orders Sender

```bash
sudo cset proc -s user -e numactl -- -C 3,17 chrt -f 80 ~/wallaroo/giles/sender/sender -h wallaroo-leader-1:7000 -m 5000000000 -s 100 -i 2_500_000 -f ~/wallaroo/testing/data/market_spread/orders/350-symbols_orders-fixish.msg -r --ponythreads=1 -y -g 57 --ponypinasio -w --ponynoblock
```

### Market Spread Cluster Shutdown

When it's time to shutdown your Market Spread cluster, you'd want to do the following.

SSH into `wallaroo-follower-1`

Run the following command to shutdown the cluster:

```bash
sudo cset proc -s user -e numactl -- -C 16,17 chrt -f 80 ~/wallaroo/utils/cluster_shutdown/cluster_shutdown wallaroo-leader-1:5050 --ponythreads=1 --ponynoblock --ponypinasio
```

## Record Information

You should allow this test to run for roughly 1/2 an hour and record the required information. What should be recorded is documented in the Wallaroo Performance Testing Guide under the [Information to Record](../../../WALLAROO_PERFORMANCE_TESTING_GUIDE.md#information-to-record) section.

## Running Two Worker Python Market Spread

### Building Wallaroo and Tooling

ssh into `wallaroo-leader-1` and build the required Wallaroo tools:

```bash
cd ~/wallaroo
make build-machida build-giles-all build-utils-cluster_shutdown
```

`scp` Wallaroo to other workers on the cluster:

```bash
scp -r -o StrictHostKeyChecking=no ~/wallaroo/ ubuntu@wallaroo-follower-1:~/wallaroo
scp -r -o StrictHostKeyChecking=no ~/wallaroo/ ubuntu@wallaroo-follower-2:~/wallaroo
scp -r -o StrictHostKeyChecking=no ~/wallaroo/ ubuntu@wallaroo-follower-3:~/wallaroo
```

### Validate Testing Environment

A script is provided to verify that the testing environment is in an optimal state for testing. To run this script, ssh into each instance and run the following:

```bash
~/wallaroo/orchestration/validate_environment.sh
```

This is the expected output:

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

### Start Metrics UI

SSH into `wallaroo-follower-2`

Start the Metrics UI:

```bash
docker run -d -u root --cpuset-cpus 10-18 --privileged  -v /usr/bin:/usr/bin:ro   -v /var/run/docker.sock:/var/run/docker.sock -v /bin:/bin:ro  -v /lib:/lib:ro  -v /lib64:/lib64:ro  -v /usr:/usr:ro  -v /tmp:/apps/metrics_reporter_ui/log  -p 0.0.0.0:4000:4000 -p 0.0.0.0:5001:5001 --name mui -h mui --net=host wallaroo-labs-docker-wallaroolabs.bintray.io/release/metrics_ui:0.5.2
```

You can verify the Metrics UI is up by visiting the IP address of `wallaroo-follower-2` with `:4000` appended. So if the IP was `54.172.117.178` you'd visit https://54.172.117.178:4000

##### Restarting the Metrics UI

If you need to restart the Metrics UI, run the following command on the machine you started the Metrics UI on:

```bash
docker restart mui
```

#### Start Giles Receiver

SSH into `wallaroo-follower-2`

Start Giles Receiver with the following command:

```bash
sudo cset proc -s user -e numactl -- -C 1,17 chrt -f 80 ~/wallaroo/giles/receiver/receiver --ponythreads=1 --ponynoblock --ponypinasio -w -l wallaroo-follower-2:5555
```

#### Start the Python Market Spread Application

SSH into `wallaroo-leader-1`

Start the Python Market Spread application Initializer with the following command:

```bash
cd ~/wallaroo/testing/performance/apps/python/market_spread

sudo PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo/machida" cset proc -s user -e numactl -- -C 1,17 chrt -f 80 ~/wallaroo/machida/build/machida --application-module market_spread -i wallaroo-leader-1:7000,wallaroo-leader-1:7001 -o wallaroo-follower-2:5555 -m wallaroo-follower-2:5001 -c wallaroo-leader-1:12500 -d wallaroo-leader-1:12501 -t -e wallaroo-leader-1:5050 -w 2 --ponythreads=1 --ponypinasio --ponynoblock
```

Start the Python Market Spread application Worker 2 with the following command:

SSH into `wallaroo-follower-3`

```bash
cd ~/wallaroo/testing/performance/apps/python/market_spread

sudo PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo/machida" cset proc -s user -e numactl -- -C 1,17 chrt -f 80 ~/wallaroo/machida/build/machida --application-module market_spread -i wallaroo-leader-1:7000,wallaroo-leader-1:7001 -o wallaroo-follower-2:5555 -m wallaroo-follower-2:5001 -c wallaroo-leader-1:12500 -n worker2 --ponythreads=1 --ponypinasio --ponynoblock
```

#### Start Giles Senders

These senders send out roughly 24k messages per second per stream, this is the current baseline for maximum performance of Python Market Spread, depending what you are testing this may need to be adjusted. Please visit the "Wallaroo Data Senders Commands" section of the [WALLAROO PERFORMANCE TESTING GUIDE](../../WALLAROO_PERFORMANCE_TESTING_GUIDE.md#wallaroo-data-senders-commands) for more information regarding adjusting these values.

SSH into `wallaroo-follower-1`

You can run the following commands individually or in a script, the only sender that must be run to completion before starting any of the others is the Initial NBBO Sender.

##### Initial NBBO Sender

```bash
sudo cset proc -s user -e numactl -- -C 1,17 chrt -f 80 ~/wallaroo/giles/sender/sender -h wallaroo-leader-1:7001 -m 350 -s 50 -i 2_500_000 -f ~/wallaroo/testing/data/market_spread/nbbo/350-symbols_initial-nbbo-fixish.msg --ponythreads=1 -y -g 46 --ponypinasio -w --ponynoblock
```

##### NBBO Sender

```bash
sudo cset proc -s user -e numactl -- -C 2,17 chrt -f 80 ~/wallaroo/giles/sender/sender -h wallaroo-leader-1:7001 -m 10000000000 -s 50 -i 2_500_000 -f ~/wallaroo/testing/data/market_spread/nbbo/350-symbols_nbbo-fixish.msg -r --ponythreads=1 -y -g 46 --ponypinasio -w --ponynoblock
```

##### Orders Sender

```bash
sudo cset proc -s user -e numactl -- -C 3,17 chrt -f 80 ~/wallaroo/giles/sender/sender -h wallaroo-leader-1:7000 -m 5000000000 -s 50 -i 2_500_000 -f ~/wallaroo/testing/data/market_spread/orders/350-symbols_orders-fixish.msg -r --ponythreads=1 -y -g 57 --ponypinasio -w --ponynoblock
```

#### Market Spread Cluster Shutdown

When it's time to shutdown your Market Spread cluster, you'd want to do the following.

SSH into `wallaroo-follower-1`

Run the following command to shutdown the cluster:

```bash
sudo cset proc -s user -e numactl -- -C 16,17 chrt -f 80 ~/wallaroo/utils/cluster_shutdown/cluster_shutdown wallaroo-leader-1:5050 --ponythreads=1 --ponynoblock --ponypinasio
```

## Record Information

You should allow this test to run for roughly 1/2 an hour and record the required information. What should be recorded is documented in the Wallaroo Performance Testing Guide under the [Information to Record](../../../WALLAROO_PERFORMANCE_TESTING_GUIDE.md#information-to-record) section.

### Deleting AWS Instances

When it's time to shutdown your AWS cluster, you'd want to do the following.

On your local machine, from the `orchestration/terraform` directory, you will want to run the same command you ran to start the cluster but with `make destroy` as opposed to `make cluster`. This is to avoid any nuances that may cause the cluster to not be deleted properly. If we ran the above command, we'd run the following:

```bash
make destroy cluster_name=<YOUR-CLUSTER-NAME> num_followers=2 force_instance=c4.8xlarge ansible_system_cpus=0,18 no_spot=true cluster_project_name=wallaroo_perf_testing ansible_install_devtools=true

```

You should see output similar to the following if your cluster shutdown properly:

```bash
Destroy complete! Resources: 5 destroyed.
==> Successfully ran terraform destroy for cluster 'perftest' in region 'us-east-1' at provider 'aws'!
==> Releasing cluster lock...
aws sdb put-attributes --region us-east-1 --domain-name \
          terraform_locking --item-name aws-us-east-1_lock --attributes \
          Name=perftest-lock,Value=free,Replace=true \
          --expected Name=perftest-lock,Value=`id -u -n`-`hostname`
==> Cluster lock successfully released!
```

You can also verify your cluster is down by visiting the AWS Console and seeing that the cluster with the name you provided shows up as terminated under the `EC2` page.
