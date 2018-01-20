# KafkaSource_SinkHole

This is an example of a simple application that reads from a KafkaSource and sends the data to a Sink that throws the data away. It is mainly intended to be used as a performance testing application to see how fast the KafkaSource can go.

## Prerequisites

- ponyc
- pony-stable
- Wallaroo

See [Wallaroo Environment Setup Instructions](https://github.com/WallarooLabs/wallaroo/book/getting-started/setup.md).

## Building

Build kafkasource_sinkhole with

```bash
make
```

## kafkasource_sinkhole argument

In a shell, run the following to get help on arguments to the application:

```bash
./kafkasource_sinkhole --help
```

## Running kafkasource_sinkhole

In a separate shell, each:

1. In a shell, start up the Metrics UI if you don't already have it running:

```bash
docker start mui
```

2. Start the application

```bash
./kafkasource_sinkhole --kafka_source_topic test --kafka_source_brokers 127.0.0.1 \
  --metrics 127.0.0.1:5001  --control 127.0.0.1:12500 --data 127.0.0.1:12501 \
  --cluster-initializer --external 127.0.0.1:5050 --ponythreads=1 \
  --ponynoblock
```

3. Send data into kafka using kafkacat or some other mechanism

4. Shut down cluster once finished processing

```bash
../../../../utils/cluster_shutdown/cluster_shutdown 127.0.0.1:5050
```
