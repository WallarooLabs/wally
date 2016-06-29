# Buffy

## Usage

Buffy must be imported as a library.

In order to allow serialization across processes, we need different Buffy-specific components  
to be compiled as the same binary. You can therefore run a Buffy primary as one of a few different  
components: a platform app, a sink node for forwarding results, or a metrics receiver for forwarding  
metrics.  

### Buffy Platform App
When you run a client, use the following command line parameters:

```--leader/-l``` sets process as leader.  
```--worker-count/-w <count>``` tells the leader how many workers to wait for.  
```--name/-n <node_name>``` sets the name for the process in the Buffy cluster.  
```--phone_home/-p <address>``` sets the address for phone home.  
```--leader-control-address/-c <address>``` sets the address for the leader's control channel address.  
```--leader-data-address/-d <address>``` sets the address for the leader's data channel address.  
```--source/-r <comma-delimited source_addresses>``` sets the addresses for the sink.  
```--sink/-k <comma-delimited sink_addresses>``` sets the addresses for the sink.  
```--metrics/-m <metrics-receiver address>``` sets the address for the metrics receiver.  
```--spike-seed <seed>``` optionally sets seed for spike.  
```--spike-delay``` set flag for spike delay.  
```--spike-drop``` set flag for spike drop.  

To run the Double Divide app, you need to kick off three processes.  The first arg is  
the leader address.  

* Leader
  * ```./app-name --leader-control-address 127.0.0.1:6000 --leader-data-address 127.0.0.1:6500 --source 127.0.0.1:7000 --sink 127.0.0.1:8000 --metrics 127.0.0.1:9000 -p 127.0.0.1:10000 -l -w 2 -n leader```

* Workers  
  * ```./app-name --leader-control-address 127.0.0.1:6000 --leader-data-address 127.0.0.1:6500 --source 127.0.0.1:7000 --sink 127.0.0.1:8000 --metrics 127.0.0.1:9000 -p 127.0.0.1:10000 -n Worker1```  
  * ```./app-name --leader-control-address 127.0.0.1:6000 --leader-data-address 127.0.0.1:6500 --source 127.0.0.1:7000   --sink 127.0.0.1:8000 --metrics 127.0.0.1:9000 -p 127.0.0.1:10000 -n Worker2```  

You can also choose to enable spiking on the node with either ```--spike-delay``` or ```--spike-drop``` flags  

### Sink Node
To run as a sink node, use the following parameters:  

```--run-sink``` runs as sink node  
```--addr/-a <address>``` sets address sink node is listening on  
```--target-addr/-t <address>``` sets address sink node sends reports to  
```--step-builder <idx>``` set index of sink step builder for this sink node  

For example:

```
./market-spread --run-sink -a 127.0.0.1:8000 -t 127.0.0.1:5555
```

If the Market Spread app is writing to a sink address of 127.0.0.1:8000, then those  
messages would be sent to this sink node.  

### Metrics Receiver
To run as Metrics Receiver, use the following parameters:  

```--run-sink``` runs as sink node (with -r to indicate this is a metrics receiver)  
```--metrics-receiver/-r``` runs as metrics-receiver node  
```--listen [Listen address``` in xxx.xxx.xxx.xxx:pppp format  
```--monitor``` Monitoring Hub address in xxx.xxx.xxx.xxx:pppp format  
```--name``` Application name to report to Monitoring Hub  
```--period``` Aggregation periods for reports to Monitoring Hub  
```--delay``` Maximum period of time before sending data  
```--report-file``` File path to write reports to  
```--report-period``` Aggregation period for reports in report-file  

For example:

```
./market-spread --run-sink -r -l 127.0.0.1:9000 -m 127.0.0.1:5001 --name market-spread --period 1  
```
