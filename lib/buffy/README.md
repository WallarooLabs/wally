# Buffy

## Usage

Buffy must be imported as a library.

When you run a client, use the following command line parameters:

```-l``` sets process as leader.  
```-w <count>``` tells the leader how many workers to wait for.
```-n <node_name>``` sets the name for the process in the Buffy cluster.
```-p <address>``` sets the address for phone home.
```--leader-control-address <address>``` sets the address for the leader's control channel address.
```--leader-data-address <address>``` sets the address for the leader's data channel address.
```--source <comma-delimited source_addresses>``` sets the addresses for the sink.
```--sink <comma-delimited sink_addresses>``` sets the addresses for the sink.
```--metrics <metrics-receiver address>``` sets the address for the metrics receiver.
```--spike-seed <seed>``` optionally sets seed for spike.
```--spike-delay``` set flag for spike delay.
```--spike-drop``` set flag for spike drop.

To run the Double Divide app, you need to kick off three processes.  The first arg is
the leader address.

* Leader
  * ```./app-name --leader-control-address 127.0.0.1:6000 --leader-data-address 127.0.0.1:6500 --source 127.0.0.1:7000 --sink 127.0.0.1:8000 --metrics 127.0.0.1:9000 -p 127.0.0.1:10000 -l -w 2 -n leader```

* Workers  
  * ```./app-name --leader-control-address 127.0.0.1:6000 --leader-data-address 127.0.0.1:6500 --source 127.0.0.1:7000 --sink 127.0.0.1:8000 --metrics 127.0.0.1:9000 -p 127.0.0.1:10000 -n Worker1```
  * ```./app-name --leader-control-address 127.0.0.1:6000 --leader-data-address 127.0.0.1:6500 --source 127.0.0.1:7000 --sink 127.0.0.1:8000 --metrics 127.0.0.1:9000 -p 127.0.0.1:10000 -n Worker2```

You can also choose to enable spiking on the node with either ```--spike-delay``` or ```--spike-drop``` flags
