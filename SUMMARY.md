# Wallaroo

* [What is Wallaroo?](book/what-is-wallaroo.md)

## Core Concepts

* [Introduction](book/core-concepts/intro.md)
* [Introducing Wallaroo Core Concepts](book/core-concepts/core-concepts.md)
* [State](book/core-concepts/state.md)
* [Working with State](book/core-concepts/working-with-state.md)
* [Partitioning](book/core-concepts/partitioning.md)

## Developing with Wallaroo
* [Choosing an Installation Option](book/getting-started/choosing-an-installation-option.md)
* Installing with Docker
  * [Setting Up Your Environment](book/getting-started/docker-setup.md)
  * [Run a Wallaroo Application in Docker](book/getting-started/run-a-wallaroo-application-docker.md)
* Installing From Source
  * [Setting up Your Environment](book/getting-started/setup.md)
    * [MacOS Installation](book/getting-started/macos-setup.md)
    * [Ubuntu Installation](book/getting-started/linux-setup.md)
  * [Run a Wallaroo Application](book/getting-started/run-a-wallaroo-application.md)
* [Conclusion](book/getting-started/conclusion.md)

<!--
### Wallaroo C++ API
* [C++ API Introduction](book/cpp/intro.md)
* [C++ Sample Application](book/cpp/sample-application.md)
* [Building a C++ Application](book/cpp/building.md)
* C++ Supplemental Info
   * [C++ Best Practices](book/cpp/best-practices.md)
   * [C++ Memory Mangement](book/cpp/memory-management.md)
   * [C++ Serialization](book/cpp/serialization.md)
* C++ API Classes
   * [Application](book/cpp/api/application.md)
   * [Computation](book/cpp/api/computation.md)
   * [Data](book/cpp/api/data.md)
   * [Key](book/cpp/api/key.md)
   * [Partition](book/cpp/api/partition.md)
   * [PartitionU64](book/cpp/api/partition-u64.md)
   * [PartitionFunction](book/cpp/api/partition-function.md)
   * [PartitionFunctionU64](book/cpp/api/partition-function-u64.md)
   * [SinkEncoder](book/cpp/api/sink-encoder.md)
   * [SourceDecoder](book/cpp/api/source-decoder.md)
   * [StateBuilder](book/cpp/api/state-builder.md)
   * [StateChange](book/cpp/api/state-change.md)
   * [StateChangeBuilder](book/cpp/api/state-change-builder.md)
   * [StateComputation](book/cpp/api/state-computation.md)
   * [State](book/cpp/api/state.md)
   * [UserFunctions](book/cpp/api/user-functions.md)
-->

## Wallaroo with Python
### Wallaroo Python API
* [Python API Introduction](book/python/intro.md)
* [Running a Wallaroo Python Application](book/python/running-a-wallaroo-python-application.md)
* [Writing Your Own Application](book/python/writing-your-own-application.md)
* [Writing Your Own Stateful Application](book/python/writing-your-own-stateful-application.md)
* [Writing Your Own Partitioned Stateful Application](book/python/writing-your-own-partitioned-stateful-application.md).
* [Word Count](book/python/word-count.md)
* [Interworker Serialization and Resilience](book/python/interworker-serialization-and-resilience.md)
* [Wallaroo Python API](book/python/api.md)

### Debugging Python Wallaroo Applications
* [Debugging](book/python/debugging.md)

## Wallaroo with Go
### Setting up Your Environment

* [Setting up Your Environment](book/go/getting-started/setup.md)
  * [MacOS Installation](book/getting-started/macos-setup.md)
  * [Ubuntu Installation](book/getting-started/linux-setup.md)
* [Run a Wallaroo Go Application](book/getting-started/run-a-wallaroo-go-application.md)
* [Conclusion](book/getting-started/conclusion.md)

### Wallaroo Go API
* [Go API Introduction](book/go/api/intro.md)
* [Writing Your Own Application](book/go/api/writing-your-own-application.md)
* [Writing Your Own Stateful Application](book/go/api/writing-your-own-stateful-application.md)
* [Word Count](book/go/word-count.md)
* [Interworker Serialization and Resilience](book/go/api/interworker-serialization-and-resilience.md)
* [Start A Go Project](book/go/api/start-a-project.md)
* [Wallaroo Go API](book/go/api/api.md)

## Appendix
* [Clustered Wallaroo](book/appendix/clustering.md)
* [Wallaroo and Virtualenv](book/appendix/virtualenv.md)
* [Wallaroo Command-Line Options](book/appendix/wallaroo-command-line-options.md)
* [TCP Decoders and Encoders](book/appendix/tcp-decoders-and-encoders.md)
* [Sending Data over TCP with Giles Sender](book/wallaroo-tools/giles-sender.md)
* [Receiving Data over TCP with Giles Receiver](book/wallaroo-tools/giles-receiver.md)
* [Monitoring Metrics with the Monitoring Hub](book/metrics/metrics-ui.md)
* [Decoding Giles Receiver Output](book/appendix/decoding-giles-receiver-output.md)
* [Wallaroo and Long-Running Data Processing and Other Workflows](book/appendix/wallaroo-and-long-running-data-processing-and-other-workflows.md)
* [Tips for using Wallaroo in Docker](book/appendix/wallaroo-in-docker-tips.md)

## Legal
* [Terms and Conditions](book/legal/terms.md)

---
<!---

### Getting Started with Wallaroo 2


* [Wallaroo Concepts](wallaroo-concepts.md)
* [Installing Wallaroo](installing-wallaroo.md)
* [Hello, Wallaroo!](hello-wallaroo.md)
* [Starting a Cluster](starting-a-cluster.md)
* [Building an Application](building-an-application.md)
* [Exploring Core Features](exploring-core-features.md)
* [Test Page](test-page.md)

### Develop
* [Wallaroo API](wallaroo-api.md)
* [Topologies](topologies.md)
* [Language Bindings](Language Bindings/readme.md)
  * [Pony](Language Bindings/pony.md)
  * [C++](cpp.md)

### Deploy
* [Recommended Production Settings](recommended-production-settings.md)
* [Manual Deployment](manual-deployment.md)
* [Cloud Deployment](cloud-deployment.md)
* [Start a Node](start-a-node.md)
* [Stop a Node](stop-a-node.md)

### Manage
* [Admin UI](admin-ui.md)
* [Troubleshoot](troubleshoot.md)

### Learn How it Works
* [Frequently Asked Questions](FAQ.md)
* [Wallaroo in Comparison](wallaroo-comparison.md)
* [Wallaroo Architecture](wallaroo-architecture.md)
* [Wallaroo Features](wallaroo-features.md)
* [Demo - Market Spread Application](demo-market-spread-application.md)

### Misc
* [Distributed Computing Resources](distributed-computing-resources.md)


### Contribute
* [Contribute to Wallaroo](contribute-to-wallaroo.md)
* [Improve the Docs](improve-the-docs.md)

### Release Notes
* [Wallaroo Roadmap](roadmap.md)
* [v1.0-201611101](v1.0-201611101.md)
-->
