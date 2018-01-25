# Autoscale

Wallaroo is designed to support scale-independent development. It can adapt to changing demands by growing or shrinking to fit the available resources. You don’t have to update any code or bother with stopping your cluster and redeploying. This set of features is called “autoscale”.

With autoscale enabled, you can add or remove workers from a running cluster. We call these “grow to fit” and “shrink to fit”, respectively (referring to the fact that the cluster grows or shrinks to fit your current resource requirements). To enable autoscale, you must build a Wallaroo binary using the `-D autoscale` command line argument. Autoscale is set by default when running `make` for building Machida or the example Wallaroo applications.

## Grow to Fit   

While a Wallaroo cluster is running, new workers can join the cluster.  To add workers to a running cluster, you must know the control channel address of one of the workers in the running cluster.  Let’s assume it’s `127.0.0.1:12500`.  The following command would allow us to add one worker to a running cluster for the `alphabet` example app:

{% codetabs name="Python", type="py" -%}
machida --application-module alphabet --in 127.0.0.1:7010 \
  --out 127.0.0.1:7002 --join 127.0.0.1:12500 --name w3 \
  --ponythreads 1
{%- language name="Go", type="go" -%}
alphabet --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
  --join 127.0.0.1:12500 --name w3
{%- endcodetabs %}

The `--in` argument specifies the port that the TCP source will listen on, and the `--out` argument specifies the target address for data output over TCP. `--join` is used to specify the control channel address of the running worker we are contacting in order to join.  `--name` is used to specify the name of the joining worker.

If you want to add more than 1 new worker at a time, you must have all joining workers contact the same running worker and all must specify the same joining worker total as the `worker_count` command line argument.  For example, if 3 workers are joining, then in our case, they could all use `--join 127.0.0.1:12500` and `--worker-count 3`.  Their command lines might be as follows:

{% codetabs name="Python", type="py" -%}
machida --application-module alphabet --in 127.0.0.1:7010 \
  --out 127.0.0.1:7002 --join 127.0.0.1:12500 --name w3 --worker-count 3 \
  --ponythreads 1

machida --application-module alphabet --in 127.0.0.1:7010 \
  --out 127.0.0.1:7002 --join 127.0.0.1:12500 --name w4 --worker-count 3 \
  --ponythreads 1

machida --application-module alphabet --in 127.0.0.1:7010 \
  --out 127.0.0.1:7002 --join 127.0.0.1:12500 --name w5 --worker-count 3 \
  --ponythreads 1
{%- language name="Go", type="go" -%}
alphabet --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
  --join 127.0.0.1:12500 --name w3 --worker-count 3

alphabet --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
  --join 127.0.0.1:12500 --name w4 --worker-count 3

alphabet --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
  --join 127.0.0.1:12500 --name w5 --worker-count 3
{%- endcodetabs %}

## Shrink to Fit

It is also possible to remove one or more workers from a running cluster. 
There are two ways to specify that workers should be removed from the cluster.  You can either specify the worker names or the total count of workers to be removed.  You must know the external channel address of one worker in the running cluster. 

You can use the `cluster_shrinker` tool to send a shrink message to this channel. For example, if the external address is `127.0.0.1:5050` and we want to remove 2 workers from the cluster, we can run the following, using the `count` argument to specify the worker count to remove:

```
cluster_shrinker --external 127.0.0.1:5050 --count 2
```

To request that workers `w2` and `w3` be removed, we can pass a comma-separated list of worker names as the `--workers` argument:

```
cluster_shrinker --external 127.0.0.1:5050 --workers w2,w3
```

To qualify for removal from the cluster, a worker must currently meet two criteria:

1. It must have no sources placed on it.
2. It must have no non-parallelized stateless computations placed on it.

If you send in a list of worker names that includes at least one invalid worker (either because the worker does not meet the 2 criteria or because it is an invalid name) then the shrink will not happen. If you send in a shrink count that’s higher than the number of workers meeting the 2 criteria, then Wallaroo will shrink by the maximum number of workers that do meet those criteria (which could be 0).

The leaving workers will migrate state to the remaining workers and then shut down. The remaining workers will then handle all work for the application.

You can query a running cluster to get a list of workers eligible for shutdown. In order to do this, pass the `--query` flag:

```
cluster_shrinker --external 127.0.0.1:5050 --query
```

