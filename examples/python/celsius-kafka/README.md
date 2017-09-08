# Celsius

This is an example of a stateless Python application that takes a floating point Celsius value from Kafka and sends out a floating point Fahrenheit value to Kafka.


## Prerequisites

- ponyc
- pony-stable
- Wallaroo
- Machida

See [Wallaroo Environment Setup Instructions](https://github.com/WallarooLabs/wallaroo/book/getting-started/setup.md).

## Running Celsius-kafka

In a separate shell, each:

0. Start kafka and create the `test-in` and `test-out` topics

One way to get kafka running with the topics:

This requires `docker-compose`:

```bash
sudo curl -L https://github.com/docker/compose/releases/download/1.15.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

```bash
cd /tmp
git clone https://github.com/effata/local-kafka-cluster
cd local-kafka-cluster
sudo ./cluster up 1 # change 1 to however many brokers are desired to be started
sudo docker exec -it local_kafka_1_1 /kafka/bin/kafka-topics.sh --zookeeper \
  zookeeper:2181 --create --partitions 4 --topic test-in --replication-factor \
  1 # to create a test-in topic; change arguments as desired
sudo docker exec -it local_kafka_1_1 /kafka/bin/kafka-topics.sh --zookeeper \
  zookeeper:2181 --create --partitions 4 --topic test-out --replication-factor \
  1 # to create a test-in topic; change arguments as desired
```

1. In a shell, start up the Metrics UI if you don't already have it running:

```bash
docker start mui
```

2. Start the application

In another shell, set up your environment variables if you haven't already done so. Assuming you installed Machida according to the tutorial instructions you would do:

```bash
export PYTHONPATH=".:$PYTHONPATH:$HOME/wallaroo-tutorial/wallaroo/machida"
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build"
```

Run `machida` with `--application-module celsius`:

```bash
machida --application-module celsius \
  --kafka_source_topic test-in --kafka_source_brokers 127.0.0.1:9092 \
  --kafka_sink_topic test-out --kafka_sink_brokers 127.0.0.1:9092 \
  --kafka_sink_max_message_size 100000 --kafka_sink_max_produce_buffer_ms 10 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:12500 --data 127.0.0.1:12501 \
  --name worker-name --external 127.0.0.1:5050 --cluster-initializer \
  --ponythreads=1
```

`kafka_sink_max_message_size` controls maximum size of message sent to kafka in a single produce request. Kafka will return errors if this is bigger than server is configured to accept.

`kafka_sink_max_produce_buffer_ms` controls maximum time (in ms) to buffer messages before sending to kafka. Either don't specify it or set it to `0` to disable batching on produce.

3. Send data into kafka using kafkacat or some other mechanism

```bash
sudo apt-get install kafkacat
```

Run the following and then type at least 4 characters on each line and hit enter to send in data (only first 4 characters are used/interpreted as a float; the appliction will throw an error and possibly segfault if less than 4 characters are sent in):

```bash
kafkacat -P -b 127.0.0.1:9092 -t test-in
```

Note: You can use `ctrl-d` to exit `kafkacat`

4. Shut down cluster once finished processing

```bash
../../../utils/cluster_shutdown/cluster_shutdown 127.0.0.1:5050
```

5. Stop kafka

If you followed the commands from Step 0 to start kafka you can stop it by:

```bash
cd /tmp/local-kafka-cluster
sudo ./cluster down # shut down cluster
```
