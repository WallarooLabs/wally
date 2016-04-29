# Buffy

## Usage

Buffy must be imported as a library.

When you run a client, use the following command line parameters:

```-l``` sets process as leader.  
```-w <count>``` tells the leader how many workers to wait for.  
```-n <node_name>``` sets the name for the process in the Buffy cluster.

To run the code, you need to kick off three processes:

1. Leader  
```./app-name 127.0.0.1:6000 -l -w 2 -n LeaderNode```

2. Workers  
```./app-name 127.0.0.1:6000 -n Worker1```
```./app-name 127.0.0.1:6000 -n Worker2```

The address passed in is the leader's address.
