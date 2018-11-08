# Metrics Protocol

In this section, we will introduce you to our Metrics Protocol. This will be useful for users who'd prefer to use their own system to handle aggregation of metrics as opposed to our Metrics UI. We will be covering how metrics are recorded in Wallaroo and the structure of messages provided by the Metrics Protocol.

Our Metrics Protocol was designed to work with an external application to handle the rollup and aggregation of Wallaroo metrics for computations, pipelines, and workers for a given Wallaroo application. Metrics data is transmitted via TCP as a Metric Message defined by the Metrics Protocol. If you are not familiar with core concept's of Wallaroo, please take a look at [Wallaroo Core Concepts](core-concepts/core-concepts.md) before proceeding. It may also be beneficial to have a look at the documentation for our [Metrics UI](wallaroo-tools/metrics-ui.md) to refamiliarize yourself with the type of data we extract from the metrics provided by the Metrics Protocol.

## How are Metrics collected in Wallaroo?

In order to have an understanding of the structure of a Metrics Message, you should know how we collect metrics in Wallaroo. Metrics in Wallaroo are collected for 3 different categories: computations, pipelines, and workers. A reporter is created for each source, sink, and coalesced sequence of computations within a Wallaroo application. Depending on where and how a message is processed, it will use an associated reporter in order to record metrics for that message. Metrics are recorded as work is processed within a given time window. As soon as a new metric is recorded outside of our time window, a Metrics Message will be created and sent off from that reporter and we'll start recording for the next time window. Why does this matter? We will receive multiple Metrics Message's for a given item within a category, depending on how many reporters there are for that item. Time windows are used because there is the chance that we won't process a message for a few window cycles and this allows us to send off metrics belonging to an older time window regardless of when the latest metric arrives.

Each reporter keeps track of the following information: the associated application, worker, pipeline, and category which the metric being recorded belongs to. Metrics are then stored for a given item within a category in each related reporter. This information is then used externally to aggregate related Metrics Message's provided by each reporter.

In order to keep a small footprint within Wallaroo, we use a histogram to store our metrics. Our histogram is composed of 65 bins, where each bin represents a time range. The value stored within that bin represents how many messages fell within that time range for that histogram's reporter. To extract the time range for a particular bin, we raise 2 to the power of that bin's index to determine the bin's max time (inclusive) and use the max of the bin before it to determine it's min time (exclusive). These range values are then represented as time in nanoseconds. We also store the min and max recorded latency for a given time window. We store only the min and max as they are values someone collecting metrics might find useful, that can be obscured by the use of ranges. Since our ranges grow exponentially, providing the min and max latency allows our user to know the best and worst case performance for the period these Metrics were recorded for.

Here's an example of the first 10 bins:

- Bin 0:  2^0 =    1,  Range:   0 < x ≤    1 nanoseconds
- Bin 1:  2^1 =    2,  Range:   1 < x ≤    2 nanoseconds
- Bin 2:  2^2 =    4,  Range:   2 < x ≤    4 nanoseconds
- Bin 3:  2^3 =    8,  Range:   4 < x ≤    8 nanoseconds
- Bin 4:  2^4 =   16,  Range:   8 < x ≤   16 nanoseconds
- Bin 5:  2^5 =   32,  Range:  16 < x ≤   32 nanoseconds
- Bin 6:  2^6 =   64,  Range:  32 < x ≤   64 nanoseconds
- Bin 7:  2^7 =  128,  Range:  64 < x ≤  128 nanoseconds
- Bin 8:  2^8 =  256,  Range: 128 < x ≤  256 nanoseconds
- Bin 9:  2^9 =  512,  Range: 256 < x ≤  512 nanoseconds
- Bin 10: 2^10 = 1024, Range: 512 < x ≤ 1024 nanoseconds

The remaining ranges can be found in the appendix below.

### How are metrics reported for each category?

Worker metrics are reported as the time of ingestion of a message on a worker from a source or another worker for a given pipeline, to the time of completion of that message on that worker or until it was handed off to the next worker.

Computation metrics are reported as the time it took to complete said computation on a given worker.

Pipeline metrics are reported as the time of ingestion from that pipeline's source to the time of completion of said pipeline on any worker.

## Notation

### Data types used in the Metrics Protocol

We will use the following notation to describe the data types used as part of the Metrics Protocol:

- U8: Unsigned  8 bit integer (1 byte)
- U16: Unsigned 16 bit integer (2 bytes)
- U32: Unsigned 32 bit integer (4 bytes)
- U64: Unsigned 64 bit integer (8 bytes)
- Array[data type]: list consisting of elements of bracketed data type
- Binary Data: Combination of any of the above data types

Any text field surrounded by `<` and `>` indicates that it is a string of varying length.

Items which are arrays are prepended by the size of said array as a U32.

## Standard Message Format

The Standard Message Format provides a way to decode each incoming message. Every message defined by the Metrics Protocol adheres to the following format:

```
Header: U32 - total size of message,
Message Type: U8 - type of HubProtocol message being sent,
Message: Binary Data - optional message
```

## Message Types

There are 3 message types defined by the Metrics Protocol: Connect, Join, and Metrics Messages. The Connect and Join messages are specific to the Metrics UI and are necessary for the TCP connection lifecycle handled by the Metrics UI. They are detailed below for informational purposes, however, they can be ignored on your end if using another system to do aggregations. Message Types are defined as follows: `Connect` - `1`, `Join` - `2`, `Metrics` - `3`.


### Metrics Message

The Metrics Message is used to send metrics for a given item within a metrics category. Additional information included is the worker and pipeline name associated with that metrics reporter. Metrics are supplied with the `metrics` Event and `metrics:<application name>` Topic.

```
Header: U32,
Message Type: U8,
Event Size: U32 ,
Event: Array[U8],
Topic Size: U32 ,
Topic: Array[U8],
Payload Size: U32,
Payload Header: U32,
Metric Name Size: U32,
Metric Name: Array[U8],
Metric Category Size: U32,
Metric Category: Array[U8],
Worker Name Size: U32,
Worker Name: Array[U8],
Pipeline Name Size: U32,
Pipeline Name: Array[U8],
ID: U16,
Latency Histogram: Array[U64] with 65 elements,
Max Recorded Latency: U64,
Min Recorded Latency: U64,
Metric Duration Period: U64,
Metrics Recording End Timestamp: U64
```

#### Metrics Message Fields:

- **Metric Name:** the name of the item within a metric category that we are reporting for.

- **Metric Category:** Possible values include: "computation" for any computation's metrics, "start-to-end" for any pipeline's metrics, and "node-ingress-egress" for any worker's metrics.

- **Worker Name:** The name of the Wallaroo worker reporting these metrics.

- **Pipeline Name:** The name of the pipeline these metrics are being reported for.

- **ID:** An ID assigned to each computation within a pipeline to indicate the order a message was processed in. Pipelines and workers will output `0` as the ID as there is no ordering for either's metrics.

- **Latency Histogram:** a 65 item array, where each value represents how many messages were processed by that reporter for that bin.

- **Max Recorded Latency:** The largest recorded latency for this Metrics Message, in nanoseconds.

- **Min Histogram Bin:** The smallest recorded latency value for this Metrics Message, in nanoseconds.

- **Period:** Duration period which the above metrics were recorded for, in nanoseconds.

- **Metrics Recording End Timestamp:** Timestamp of when this Metrics Message's period ended recording, in nanoseconds.

### Other Message Types

Below we'll go over the other message types provided by the Metrics Protocol.

#### Connect Message

The connect message is used to notify the Metrics UI that a new connection is being established to the TCP server.

```
Header: U32,
Message Type: U8
```

#### Metrics Join Message

The metrics join message is used to join the `metrics:<app-name>` channel in the Metrics UI.

```
Header: U32,
Message Type: U8,
Topic Size: U32,
Topic: Array[U8],
Worker Name Size: U32,
Worker Name: Array[U8]
```
