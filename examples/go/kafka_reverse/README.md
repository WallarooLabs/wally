# Kafka Reverse

## About The Application

This is an example application that receives strings as input from Kafka and outputs the reversed strings to Kafka.

### Input

The inputs of the "Kafka Reverse" application are strings. Here's an example input message, written as a Go string:

```
`hello` -- the string "hello"
```

### Output

The outputs of the application are strings. Here's an example output message, written as a Go string:

`olleh` -- the string `"olleh"` (`"hello"` reversed)

### Processing

The `Decoder`'s `Decode(...)` method creates a string from the value represented by the payload. The string is then sent to the `Reverse` computation where it is reversed. The reversed string is then sent to `Encoder`'s `Encode(...)` method, where a newline is appended to the string.

## Building Kafka Reverse

In order to build the application you will need a Wallaroo environment. Please visit our [setup](https://docs.wallaroolabs.com/book/go/getting-started/choosing-an-installation-option.html) instructions if you have not already done so.

You will need a new shell to build this application (please see [starting a new shell](https://docs.wallaroolabs.com/book/getting-started/starting-a-new-shell.html) for details). Open a shell and go to the `examples/go/kafka_reverse` directory.

In the kafka_reverse directory, run `make`.

## Running Kafka Reverse

In order to run the application you will need the Cluster Shutdown tool. We provide instructions for building these tools yourself. Please visit our [setup](https://docs.wallaroolabs.com/book/go/getting-started/choosing-an-installation-option.html) instructions if you have not already done so.

You will also need access to a Kafka cluster.

You will need five separate shells to run this application (please see [starting a new shell](https://docs.wallaroolabs.com/book/getting-started/starting-a-new-shell.html) for details). Open each shell and go to the `examples/go/kafka_reverse` directory.

### Shell 1: Metrics

Start up the Metrics UI if you don't already have it running:

```bash
metrics_reporter_ui start
```

You can verify it started up correctly by visiting [http://localhost:4000](http://localhost:4000).

If you need to restart the UI, run:

```bash
metrics_reporter_ui restart
```

When it's time to stop the UI, run:

```bash
metrics_reporter_ui stop
```

If you need to start the UI after stopping it, run:

```bash
metrics_reporter_ui start
```

### Shell 2: Kafka setup and listener

#### Start kafka and create the `test-in` and `test-out` topics

You need kafka running for this example. Ideally you should go to the kafka website (https://kafka.apache.org/) to properly configure kafka for your system and needs. However, the following is a quick/easy way to get kafka running for this example:

This requires `docker-compose`:

Ubuntu:

```bash
sudo curl -L https://github.com/docker/compose/releases/download/1.15.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

**NOTE:** You might need to run with sudo depending on how you set up Docker.

Clone local-kafka-cluster project and run it:

```bash
cd /tmp
git clone https://github.com/effata/local-kafka-cluster
cd local-kafka-cluster
./cluster up 1 # change 1 to however many brokers are desired to be started
sleep 1 # allow kafka to start
docker exec -i local_kafka_1_1 /kafka/bin/kafka-topics.sh --zookeeper \
  zookeeper:2181 --create --partitions 4 --topic test-in --replication-factor \
  1 # to create a test-in topic; change arguments as desired
docker exec -i local_kafka_1_1 /kafka/bin/kafka-topics.sh --zookeeper \
  zookeeper:2181 --create --partitions 4 --topic test-out --replication-factor \
  1 # to create a test-out topic; change arguments as desired
```

**Note:** The `./cluster up 1` command outputs `Host IP used for Kafka Brokers is <YOUR_HOST_IP>`.

#### Set up a listener to monitor the Kafka topic the application will publish results to. We usually use `kafkacat`.

`kafkacat` can be installed via:

```bash
docker pull ryane/kafkacat
```

##### Run `kafkacat` from Docker

Set the Kafka broker IP address:

**NOTE:** If you're running Wallaroo in Docker, you will need to replace the following with `export KAFKA_UP=*IP OUTPUT BY ./cluster up 1 COMMAND*` instead.

```bash
export KAFKA_IP=$(docker inspect local_kafka_1_1 | grep kafka_ip | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
```

To run `kafkacat` to listen to the `test-out` topic via Docker:

```bash
docker run --rm -i --name kafkacatconsumer ryane/kafkacat -C -b ${KAFKA_IP}:9092 -t test-out -q
```

### Shell 3: Kafka Reverse

Set the Kafka broker IP address:

**NOTE:** If you're running Wallaroo in Docker, you will need to replace the following with `export KAFKA_UP=*IP OUTPUT BY ./cluster up 1 COMMAND*` instead.

```bash
export KAFKA_IP=$(docker inspect local_kafka_1_1 | grep kafka_ip | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
```

Run Kafka reverse:

```bash
./kafka_reverse \
  --kafka_source_topic test-in --kafka_source_brokers ${KAFKA_IP}:9092 \
  --kafka_sink_topic test-out --kafka_sink_brokers ${KAFKA_IP}:9092 \
  --kafka_sink_max_message_size 100000 --kafka_sink_max_produce_buffer_ms 10 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --name worker-name --external 127.0.0.1:5050 --cluster-initializer \
  --ponythreads=1 --ponynoblock
```

`kafka_sink_max_message_size` controls maximum size of message sent to kafka in a single produce request. Kafka will return errors if this is bigger than server is configured to accept.

`kafka_sink_max_produce_buffer_ms` controls maximum time (in ms) to buffer messages before sending to kafka. Either don't specify it or set it to `0` to disable batching on produce.

### Shell 4: Sender

Send data into Kafka. Again, we use `kafakcat`.

Set the Kafka broker IP address:

**NOTE:** If you're running Wallaroo in Docker, you will need to replace the following with `export KAFKA_UP=*IP OUTPUT BY ./cluster up 1 COMMAND*` instead.

```bash
export KAFKA_IP=$(docker inspect local_kafka_1_1 | grep kafka_ip | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
```

Run the following to send the numbers 1 - 100 to be reversed:

```bash
seq 1 100 | docker run --rm -i --name kafkacatproducer ryane/kafkacat -P -b ${KAFKA_IP}:9092 -t test-in
```

## Reading the Output

The output will be printed to the console in the first shell. Each line should be the reverse of a word found in the `words.txt` file.

## Shell 5: Shutdown

You can shut down the cluster with this command at any time:

```bash
cluster_shutdown 127.0.0.1:5050
```

You can shut down the kafkacat consumer by pressing Ctrl-c from its shell.

### Stop kafka

NOTE: You might need to run with sudo depending on how you set up Docker.

If you followed the commands earlier to start kafka you can stop it by running:

```bash
cd /tmp/local-kafka-cluster
./cluster down # shut down cluster
```

You can shut down the Metrics UI with the following command:

```bash
metrics_reporter_ui stop
```
