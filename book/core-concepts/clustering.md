# Clustered Wallaroo

Wallaroo allows an application to be run on multiple workers working together in a cluster. Wallaroo handles distributing work across the cluster at startup, such that no additional work is required on the developer's part.

A Wallaroo cluster does not have a continuously-running centralized manager for its workers. Coordination is all done on a decentralized basis. At cluster startup, one worker assumes the role of "initializer." The initializer is responsible for coordinating application startup. A worker is deemed to be an initializer by passing the `--cluster-initializer` command line argument. 

## Starting a Wallaroo cluster

### --worker-count

The initializer of a Wallaroo cluster needs to be started with the `--worker-count` option. `--worker-count 2` would tell the initializer to wait until the cluster has 2 members before starting up the application.

### --name

Each member of the cluster needs a unique name. The `--name` command line option is used to provide a worker name.

### --control-channel

The `--control-channel` flag serves two slightly different but related roles based on whether the worker is the initializer:

- The initializer uses the `--control-channel` flag to indicate an IP address that it should listen for incoming cluster setup connections.
- Non-initializers should be supplied with the initializer's control channel address to know where to find the initializer so that they can join the cluster.

The values for --control-channel should be the same address across all members of the cluster.

### --external

The `--external` flag sets the IP address that the Wallaroo worker should listen for administrative messages like "rotate logs" or "shut down cluster." When running a Wallaroo cluster, it is advised that you provide an address for administrative messages. 

The IP address supplied to `--external` must be unique amongst each worker in a cluster.

## Example

Imagine for a moment you have a Wallaroo Python application like our [Alphabet Partitioned example](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/python/alphabet_partitioned). Alphabet Partitioned starts up a 2 worker cluster. However, it does it on a single machine so it might be less than obvious what the specific IP addresses are that we are passing.

For the duration of this example, let's assume that we are starting a 2 worker cluster where:

- The initializer is running on 192.168.1.100 
- The 2nd worker will be running on 192.168.1.110 
- We will output results to 192.168.1.120:7002
- Our metrics host is running on 192.168.1.130:5001


The Alphabet Partitioned example has us start the initializer as:

```bash
machida --application-module alphabet_partitioned --in 127.0.0.1:7010 \
  --out 127.0.0.1:7002 --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 \
  --data 127.0.0.1:6001 --worker-count 2 --cluster-initializer \
  --external 127.0.0.1:6002 --ponythreads=1
```

For the sake of clustering, we would want to change that to:

```bash
machida --application-module alphabet_partitioned --in 192.168.1.100:7010 \
  --out 192.168.1.120:7002 --metrics 192.168.1.130:5001 \
  --control 192.168.1.100:6000 --data 192.168.1.100:6001 --worker-count 2 \
  --external 192.168.1.100:6002 --cluster-initializer --ponythreads=1
```

The Alphabet Partitioned example has us start our 2nd worker as:

```bash
machida --application-module alphabet_partitioned \
  --out 127.0.0.1:7002 --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 \
  --external 127.0.0.1:6010 --name worker-2 --ponythreads=1
```

For the sake of clustering, we would want to change that to:

```bash
machida --application-module alphabet_partitioned \
  --out 192.168.1.120:7002 --metrics 192.168.1.130:5001 \
  --control 192.168.1.100:6000 --external 192.168.1.110:8888 --name worker-2 \
  --ponythreads=1
```

It's important to note that when we started the 2nd worker:

- `--control` is a remote address where the initializer is listening
- `--external` is any local address that we want to listen on

## Restarting workers

When a cluster is starting up, all members will save information about the cluster to local disk. If a member exits and is restarted, it uses the saved information to reconnect to the running cluster. By default, cluster information is stored in `/tmp`. You can change the directory using the `--resilience-dir` parameter.

Resilience files are based on the name you supply the worker so starting different applications or clusters and reusing names can lead to odd results if you have leftover files in your resilience directory. To avoid any weirdness, you should use our clean shutdown tool or make sure to "manually" clean your resilience directory. For example, if you were using `/tmp/wallaroo` as a resilience directory, you can manually clean it by running `rm -rf /tmp/wallaroo/` to remove all cluster information files.

## Shutting down a cluster

Wallaroo comes with a [cluster shutdown tool](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/utils/cluster_shutdown) that can be used to shut down a running cluster.
