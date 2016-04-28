# Buffy

## Usage

Buffy is currently hardcoded to run a Double/Divide app over two Buffy processes.

```-l``` sets process as leader.  
```-w <count>``` tells the leader how many workers to wait for.  
```--id <node_id>``` sets the id for the process in the Buffy cluster.  

To run the code, you need to kick off three processes:

1. Leader  
```./buffy-pony 127.0.0.1:6000 -l -w 2 -n LeaderNode```

2. Workers  
```./buffy-pony 127.0.0.1:6000 -n Worker1```
```./buffy-pony 127.0.0.1:6000 -n Worker2```

The address passed in is the leader's address.
