# datagen_kafkasink

This is an example of a simple application that generates data via a data generator and sends the data to a KafkaSink. It is mainly intended to be used as a performance testing application to see how fast the KafkaSink can go.

## Prerequisites

- ponyc
- pony-stable
- Wallaroo

See [Wallaroo Environment Setup Instructions](https://github.com/WallarooLabs/wallaroo/book/getting-started/setup.md).

## Building

Build datagen_kafkasink with

```bash
make
```

## datagen_kafkasink argument

In a shell, run the following to get help on arguments to the application:

```bash
./datagen_kafkasink --help
```

## Running datagen_kafkasink

In a separate shell, each:

1. In a shell, start up the Metrics UI if you don't already have it running:

```bash
docker start mui
```

2. Start the application

```bash
./datagen_kafkasink --kafka_sink_topic test --kafka_sink_brokers 127.0.0.1 \
  --metrics 127.0.0.1:5001  --control 127.0.0.1:12500 --data 127.0.0.1:12501 \
  --kafka_sink_max_message_size 100000 --kafka_sink_max_produce_buffer_ms 10 \
  --cluster-initializer --external 127.0.0.1:5050 --ponythreads=1 \
  --ponynoblock
```

`kafka_sink_max_message_size` controls maximum size of message sent to kafka in a single produce request. Kafka will return errors if this is bigger than server is configured to accept.

`kafka_sink_max_produce_buffer_ms` controls maximum time (in ms) to buffer messages before sending to kafka. Either don't specify it or set it to `0` to disable batching on produce.

3. Shut down cluster once finished processing

```bash
../../../../utils/cluster_shutdown/cluster_shutdown 127.0.0.1:5050
```
