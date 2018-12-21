---
layout: default
title: Admin UI
---

The Wallaroo Admin UI displays data that is collected while an application is running.  Information is generated and collected in Wallaroo's metrics subsystem.

The three main componenets of the metrics subssystem are metrics collector, metrics receiver and monitoring hub.


__Mertrics Collector__

Wallaroo is responsible for generating metrics for every message processed.  Uniquely identified sources, computations, and sinks define an application.  You can think of these stages as constituting a graph.  The time spent processing a particular message is measured and logged. These reports are locally staged in buffers and periodically sent to the metrics receiver.  It is important to note that no data is lost due to compression of data between the metrics collector and metrics receiver.

__Metrics Reveiver__

The metrics receiver runs as a separate process within Wallaroo.  The metrics collector is responsible for sending summaries to the metrics receiver; this happens over TCP.

The metrics receiver aggregates performance metrics.  Aggregations include stages (computations), proxies (node boundaries), sources and sinks (application boundaries).  

Various reports use these aggregates, latency histogram, throughput history, and stages.

The latency histogram uses fixed bins.   The benefits to using these include that they are processor inexpensive and easy to add any other fixed bin histogram.  They can answer the question, what % of the events complete in less than X ms?

Throughput history is a count of events completed per stage per second.

The timestamps for all metrics calculations are taken locally at each node.  Wallaroo assumes that node clocks are synchronized. A later version will address clock drift and other potential timing issues.

__Monitoring Hub__

??? how is this wired  up into receiver 

??? what was this written? 

??? how would you configure this

Data is received via TCP





[Next](troubleshoot)
