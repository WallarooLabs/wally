# Current Limitations

The following is a list of limitations and gotchas with existing supported features that still need to be addressed. If any of these issues are a blocker for you that has to be resolved, please [contact us](README.md#getting-help). We're happy to get feedback and work with clients on improving Wallaroo.

## Metrics

* [Issue #766](https://github.com/WallarooLabs/wallaroo/issues/766) Metric collection is not optional. This means `--metrics` command line argument is required, and that even if you are not using metrics, you will still get the small performance hit.

### Metrics UI

* [Issue #1193](https://github.com/WallarooLabs/wallaroo/issues/1193) The Metrics UI does not update throughput graphs unless new data is processed, which means the graph is a representation of processed data only.

## Pipelines

* [Issue #906](https://github.com/WallarooLabs/wallaroo/issues/906) We do not currently support explicit choices in the topology graph. Pipelines are linear (with the exception of partitions).

### Sources

* [Issue #894](https://github.com/WallarooLabs/wallaroo/issues/894) [Issue #915](https://github.com/WallarooLabs/wallaroo/issues/915) Sources currently only run on the initializer worker.
* [Issue #900](https://github.com/WallarooLabs/wallaroo/issues/900) Sources are not replayable. There is no mechanism for acking back to an external system from a Wallaroo source.

### Sinks

* [Issue #1009](https://github.com/WallarooLabs/wallaroo/issues/1009) Each sink is currently duplicated on every worker to reduce latency. But with enough workers, this will cause an excessive number of connections to external systems.

## Clustering

* [Issue #1191](https://github.com/WallarooLabs/wallaroo/issues/1191) No matter what name you give to the initializer worker, it will currently be renamed "initializer".

## Logging

* [Issue #106](https://github.com/WallarooLabs/wallaroo/issues/106) We do not yet provide a logger, so you must currently rely on print statements.
