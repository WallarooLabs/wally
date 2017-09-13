# Current Limitations

The following is a list of limitations and gotchas with existing supported features that still need to be addressed. If any of these issues are a blocker for you that has to be resolved, please [contact us](README.md#getting-help). We're happy to get feedback and work with clients on improving Wallaroo.

## State Partitions

* State partitions only support a static set of keys defined at startup (https://github.com/WallarooLabs/wallaroo/issues/751).
* Running a partition with fewer keys than there are workers in the cluster will currently lead to process failure (https://github.com/WallarooLabs/wallaroo/issues/956 and https://github.com/WallarooLabs/wallaroo/issues/947).
* When we initialize state in a state partition, we do not pass in information about the key associated with that state (https://github.com/WallarooLabs/wallaroo/issues/462).
* We only support a single partition function per state partition. This means that you must use that same partition function for any pipeline that interacts with that state partition (https://github.com/WallarooLabs/wallaroo/issues/464).

## Metrics

* Metric collection is not optional. This means `--metrics` command line argument is required, and that even if you are not using metrics, you will still get the small performance hit (https://github.com/WallarooLabs/wallaroo/issues/766).

## Pipelines

* We do not currently support arbitrary computation graphs. Pipelines are linear (with the exception of partitions) (https://github.com/WallarooLabs/wallaroo/issues/906).

### Sources

* Sources currently only run on the initializer worker (https://github.com/WallarooLabs/wallaroo/issues/894 and https://github.com/WallarooLabs/wallaroo/issues/915).
* Sources are not replayable. There is no mechanism for acking back to an external system from a Wallaroo source (https://github.com/WallarooLabs/wallaroo/issues/900).

### Sinks

* A pipeline currently supports at most one sink (https://github.com/WallarooLabs/wallaroo/issues/1084).
* Each sink is currently duplicated on every worker to reduce latency. But with enough workers, this will cause an excessive number of connections to external systems (https://github.com/WallarooLabs/wallaroo/issues/1009).
* We support dynamically created Sources (for example, as connections are created over TCP to a Wallaroo application), but we do not currently support dynamically created sinks (https://github.com/WallarooLabs/wallaroo/issues/1059).

## Clustering

* We can only recover from one worker failure at a time. If more than one worker crashes simultaneously, recovery will deadlock (https://github.com/WallarooLabs/wallaroo/issues/1018 and https://github.com/WallarooLabs/wallaroo/issues/1019).
* No matter what name you give to the initializer worker, it will currently be renamed "initializer" (https://github.com/WallarooLabs/wallaroo/issues/1191).

## Logging

* We do not yet provide a logger, so you must currently rely on print statements (https://github.com/WallarooLabs/wallaroo/issues/106).
