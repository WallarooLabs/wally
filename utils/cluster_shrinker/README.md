# Cluster Shrinker Tool

`cluster_shrinker` is used to tell a running cluster to reduce the number of workers in the cluster or to query the cluster for information about how many workers are eligible for removal.

## Build

```bash
make
```

## Run

You must know the external address for a running worker in the cluster in order to send in a shrink message.

There are three ways to use this tool:

1) Specify the number of workers to remove from the cluster.

Wallaroo will remove as many workers as are eligible for removal up to the number provided as the `--count` argument. For example (assuming a worker in the cluster is listening on `127.0.0.1:5050`),

```bash
./cluster_shrinker --external 127.0.0.1:5050 --count 2
```

would remove up to 2 workers from the cluster, depending on how many are eligible.

2) Specify the names of workers to remove from the cluster.

If you pass in the names (comma-separated) of running workers as the `--workers` argument, then Wallaroo will try to remove them. For example:

```bash
./cluster_shrinker --external 127.0.0.1:5050 --workers worker2,worker3
```

3) Query the cluster for information about workers eligible for removal.

If you use the `--query` flag, then Wallaroo will inform you both how many workers and which workers are eligible for removal. This reply will be printed to stdout. For example:

```bash
./cluster_shrinker --external 127.0.0.1:5050 --query
```




