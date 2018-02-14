# Current Limitations

The following is a list of limitations and gotchas with existing supported features that still need to be addressed. If any of these issues are a blocker for you that has to be resolved, please [contact us](README.md#getting-help). We're happy to get feedback and work with clients on improving Wallaroo.

## State Partitions

* [Issue #751](https://github.com/WallarooLabs/wallaroo/issues/751) State partitions only support a static set of keys defined at startup.
* [Issue #956](https://github.com/WallarooLabs/wallaroo/issues/956) [Issue #947](https://github.com/WallarooLabs/wallaroo/issues/947) Running a partition with fewer keys than there are workers in the cluster will currently lead to process failure.
* [Issue #462](https://github.com/WallarooLabs/wallaroo/issues/462) When we initialize state in a state partition, we do not pass in information about the key associated with that state.
* [Issue #464](https://github.com/WallarooLabs/wallaroo/issues/464) We only support a single partition function per state partition. This means that you must use that same partition function for any pipeline that interacts with that state partition.

## Metrics

* [Issue #766](https://github.com/WallarooLabs/wallaroo/issues/766) Metric collection is not optional. This means `--metrics` command line argument is required, and that even if you are not using metrics, you will still get the small performance hit.

### Metrics UI

* [Issue #1193](https://github.com/WallarooLabs/wallaroo/issues/1193) The Metrics UI does not update throughput graphs unless new data is processed, which means the graph is a representation of processed data only.

## Pipelines

* [Issue #906](https://github.com/WallarooLabs/wallaroo/issues/906) We do not currently support arbitrary computation graphs. Pipelines are linear (with the exception of partitions.

### Sources

* [Issue #894](https://github.com/WallarooLabs/wallaroo/issues/894) [Issue #915](https://github.com/WallarooLabs/wallaroo/issues/915) Sources currently only run on the initializer worker.
* [Issue #900](https://github.com/WallarooLabs/wallaroo/issues/900) Sources are not replayable. There is no mechanism for acking back to an external system from a Wallaroo source.

### Sinks

* [Issue #1009](https://github.com/WallarooLabs/wallaroo/issues/1009) Each sink is currently duplicated on every worker to reduce latency. But with enough workers, this will cause an excessive number of connections to external systems.
* [Issue #1059](https://github.com/WallarooLabs/wallaroo/issues/1059) We support dynamically created Sources (for example, as connections are created over TCP to a Wallaroo application), but we do not currently support dynamically created sinks.

## Clustering

* [Issue #1018](https://github.com/WallarooLabs/wallaroo/issues/1018) [Issue #1019](https://github.com/WallarooLabs/wallaroo/issues/1019) We can only recover from one worker failure at a time. If more than one worker crashes simultaneously, recovery will deadlock.
* [Issue #1191](https://github.com/WallarooLabs/wallaroo/issues/1191) No matter what name you give to the initializer worker, it will currently be renamed "initializer".

## Logging

* [Issue #106](https://github.com/WallarooLabs/wallaroo/issues/106) We do not yet provide a logger, so you must currently rely on print statements.
