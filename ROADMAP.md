# Wallaroo Roadmap

Please note that this document is meant to provide high-level visibility into the work we have planned for Wallaroo. The roadmap can change at any time. Work is prioritized in part by the needs our clients and partners. If you are interested in working with us, please contact us at [hello@wallaroolabs.com](mailto:hello@wallaroolabs.com)

## Improve the installation process

Our current installation process is quite manual at the moment. We had two choices:

- Wrap it all up in a script that if it failed would be hard to diagnose
- Make it very transparent but more work for the user

For our first pass, we've gone with the 2nd option. We are automating the installation where people ran into problems with an idea towards making as many things as possible available via precompiled binaries.

## Autoscale

Wallaroo has been built to provide programmers with a scale-agnostic API. New workers can be added to a running Wallaroo cluster. Existing workers can be removed from a running cluster. Wallaroo will adapt to both scenarios by redistributing work and continuing to process data without having to restart the cluster. We aren't quite there yet with a full-featured rock solid autoscaling, but we are close. 

Full support is planned for Q4 2017.

You can follow our progress on [GitHub](https://github.com/WallarooLabs/wallaroo/projects/8).

## Handle multiple concurrent failures

Handling failure in a distributed system is tough. The difficulty in doing it correctly is one of the reasons we are building Wallaroo. Wallaroo's failure recovery protocols are currently able to handle individual failures at a time. If more than one process were to fail at the same time or if a failure were to occur while recovery is underway, "bad things" will happen.

Handling multiple concurrent failures is considerably harder than managing them one a time. The possible interleavings of errors are vast. We have work planned to allow Wallaroo to survive simultaneous failures.

Handling multiple concurrent failures will be an ongoing project with the bulk of the work completed by the end of 2017.

You can follow our progress on [GitHub](https://github.com/WallarooLabs/wallaroo/projects/10).

## Exactly-once message processing

Exactly-once message processing is the holy grail of data processing. You should get the same correct results from a system that encountered failures while processing as one that ran without issue. 

Wallaroo supports exactly-once message processing by doing at-least-once message delivery combined with deduplication. Together this means that we can replay work and guarantee that we won't process a message more than once. Exactly-once works well within Wallaroo. 

However, additional support is needed when interfacing with external systems. To complete this work, Wallaroo needs:

- To support message replay from external sources
- An acknowledgment and deduplication protocol with external sink to prevent duplicate output messages

We are currently planning on completing this work by early Q1 2018.

You can follow our progress on [GitHub](https://github.com/WallarooLabs/wallaroo/projects/5).

## Additional language bindings

We will be adding support for additional languages based on user demand. Currently, we are getting requests for Python 3 and Go. We also have JavaScript on our roadmap.

General availability of Python 3 and Go is planned for Q4 2017.

## Survive machine failure/Data replication

Wallaroo can recover state after a process failure by replaying from an event log. If the machine the event log is on is lost, then recovery isn't possible. We are planning to add data replication with a Wallaroo cluster to address machine loss. Once in place, Wallaroo should be able to survive the loss of individual machines by switching from a primary state object to one of its replicas.

You can follow our progress on [GitHub](https://github.com/WallarooLabs/wallaroo/projects/3).

## Long-running and Micro-batch workloads

Wallaroo currently supports streaming data workloads. We are in the process of working with clients to identify common long-running and micro-batch use cases that Wallaroo should support. We'll be adding additional APIs to make writing Wallaroo batch jobs as simple as our streaming jobs.

Working to support various workloads will be an ongoing task. Please contact us if you are interested in making sure your workload is supported.

The first new API to support micro batch workloads with be appearing in Q4 2017.

