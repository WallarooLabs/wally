# Wallaroo Concepts

## Components

**Wallaroo Core**

**Merrick** A process that writes incoming TCP messages to file, created specifically for the use of writing outgoing Wallaroo metrics to file.

**Robson** A process that writes Wallaroo Metric Stats to file, using the output of merrick received-metrics.txt to generate the stats.

**Integration Test Suite**
Wallaroo provides a purpose-built integration testing framework to ensue the platform and applications are functioning correctly. The test suite is made up of the following components:

* **Giles** Test data source and data capture
* **Spike** Introduces damage into data and data flow

___

## DEFINITIONS

**Node** A machine that is a member of a cluster

**Cluster** A group of nodes used for processing

**Worker** A Wallaroo process

**Computation** Transformation of input data to output

**Pipeline** A series of computations

**Application** One or more related pipelines.  An application is an abstraction that we provide to help you organize various pieces of business logic. 

**Source** Input point for data from external systems into an application

**Sink** Output point from an application to external systems

**Step** A user-defined computation

**Trace**

**State**

___


## State Management

Wallaroo provides application developers with integrated state management.  These are in-memory and resilient.  State recovery is handled by the system.  In the recovery procedure of a process or node failure, state is restored trough snapshot recovery and message replay.

There are additional controls in place to distribute any stateful data structures across the cluster to achieve appropriate SLAs.
