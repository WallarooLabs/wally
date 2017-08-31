# Cluster Shutdown Tool

`cluster_shutdown` is used to gracefully shutdown a running Wallaroo cluster.

## Build

```bash
make
```

## Run

```bash
./cluster_shutdown ADDRESS:PORT
```

For example, if a cluster member had its external message channel running on port 8888 of 192.168.1.100 then running `./cluster_shutdown 192.168.1.100:8888` would send a clean shutdown message to the cluster.


