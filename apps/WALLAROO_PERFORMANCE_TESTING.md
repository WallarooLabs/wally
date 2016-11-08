# Performance Testing on AWS/Packet

If you have not followed the setup instructions in the orchestration/terraform [README](https://github.com/Sendence/buffy/tree/master/orchestration/terraform) please do so before continuing.

##Configuring Cluster:

Once set up, an AWS cluster can be started with the following command:
```
make cluster cluster_name=<YOUR_CLUSTER_NAME> mem_required=30 cpus_required=16 num_followers=0 force_instance=c4.4xlarge spot_bid_factor=100 ansible_system_cpus=0,8 ansible_isolcpus=false
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

### Metrics And Reports UI

You need to create a docker network for the UI's with the following command:
```
docker network create buffy-leader
```

To run the Metrics UI:
```
docker run -d -u root --cpuset-cpus 0,8 --privileged  \
-v /usr/bin:/usr/bin:ro   -v /var/run/docker.sock:/var/run/docker.sock \
-v /bin:/bin:ro  -v /lib:/lib:ro  -v /lib64:/lib64:ro  -v /usr:/usr:ro  \
-v /tmp:/apps/metrics_reporter_ui/log  \
-p 0.0.0.0:4000:4000 -p 0.0.0.0:5001:5001 \
-e "BINS_TYPE=demo" -e "RELX_REPLACE_OS_VARS=true" \
--name mui -h mui --net=buffy-leader \
docker.sendence.com:5043/wallaroo-metrics-ui:latest
```

To run the Reports UI:
```
docker run -d -u root --cpuset-cpus 0,8 --privileged \
-v /usr/bin:/usr/bin:ro   -v /var/run/docker.sock:/var/run/docker.sock \
-v /bin:/bin:ro  -v /lib:/lib:ro  -v /lib64:/lib64:ro  -v /usr:/usr:ro  \
-v /tmp:/apps/market_spread_reports_ui/log \
-p 0.0.0.0:4001:4001 -p 0.0.0.0:5555:5555 \
--name aui -h aui --net=buffy-leader \
docker.sendence.com:5043/wallaroo-market-spread-reports-ui:latest
```

###Running Market Spread Jr

You'll need to clone the repo:
```
git clone https://github.com/sendence/buffy.git
```

To build Market Spread Jr:
```
make arch=amd64 build-apps-market-spread
```

To build Giles Sender:
```
make arch=amd64 build-giles-sender
```

###AWS
to run the Market Spread Jr application you must be in it's directory:
```
sudo cset proc -s user -e numactl -- -C 1-4,7 chrt -f 80 ./market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -f ../../demos/marketspread/initial-nbbo-fixish.msg -e 150000000 --ponythreads 4 --ponypinasio
```

To run the NBBO Sender: (must be started before Orders so that the initial NBBO can be set)
```
sudo cset proc -s user -e numactl -- -C 5,7 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7000 -m 100000000 -s 300 -i 2_500_000 -f ~/buffy/demos/marketspread/350k-nbbo-fixish.msg -r --ponythreads=1 -y -g 46 --ponypinasio```

To run the Orders Sender:
```
sudo cset proc -s user -e numactl -- -C 6,7 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7001 -m 50000000 -s 300 -i 5_000_000 -f ~/buffy/demos/marketspread/350k-orders-fixish.msg -r --ponythreads=1 -y -g 57 --ponypinasio
```

###Packet

to run the Market Spread Jr application you must be in it's directory:

```
sudo cset proc -s user -e numactl -- -C 1-4,7 chrt -f 80 ./market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -f ../../demos/marketspread/initial-nbbo-fixish.msg -e 150000000 --ponythreads 4 --ponypinasio
```

To run the NBBO Sender: (must be started before Orders so that the initial NBBO can be set)

```
sudo cset proc -s user -e numactl -- -C 5,7 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7000 -m 100000000 -s 300 -i 2_500_000 -f ~/buffy/demos/marketspread/350k-nbbo-fixish.msg -r --ponythreads=1 -y -g 46 --ponypinasio
```

To run the Orders Sender:

```
sudo cset proc -s user -e numactl -- -C 6,7 chrt -f 80 ~/buffy/giles/sender/sender -b 127.0.0.1:7001 -m 50000000 -s 300 -i 5_000_000 -f ~/buffy/demos/marketspread/350k-orders-fixish.msg -r --ponythreads=1 -y -g 57 --ponypinasio
```