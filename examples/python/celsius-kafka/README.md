# Celsius

## About The Application

This is an example of a stateless Python application that takes a floating point Celsius value from Kafka and sends out a floating point Fahrenheit value to Kafka.

### Input

The inputs of the "Celsius Kafka" application are floats in ascii text. Here's an example message:

```
"1.8"
```

### Output

Celius will output messages that are the string representation of the converted Fahrenheit value. Each incoming message will generate a single corresponding output.

### Processing

The `decoder` function creates a float from the value represented by the payload. The float value is then sent to the `multiply` computation where it is multiplied by `1.8`, and the result of that computation is sent to the `add` computation where `32` is added to it. The resulting float is then sent to the `encoder` function, which converts it to an outgoing sequence of bytes.

## Running Celsius Kafka

In order to run the application you will need Machida, Giles Sender, and the Cluster Shutdown tool. We provide instructions for building these tools yourself and we provide prebuilt binaries within a Docker container. Please visit our [setup](https://docs.wallaroolabs.com/book/getting-started/choosing-an-installation-option.html) instructions to choose one of these options if you have not already done so.

You will also need access to a Kafka cluster. This example assumes that there is a Kafka broker listening on port `9092` on `127.0.0.1`.

**NOTE:** If running in Docker, the kafkfa cluster and kafkacat should be run from your host and not within the Docker container.

You will need five separate shells to run this application. Open each shell and go to the `examples/python/celsius-kafka` directory.

### Shell 1: Metrics

Start up the Metrics UI if you don't already have it running.

Ubuntu users who are using the Metrics UI Docker image:

```bash
docker start mui
```

Wallaroo in Docker and Wallaroo in Vagrant users:

```bash
metrics_reporter_ui start
```

You can verify it started up correctly by visiting [http://localhost:4000](http://localhost:4000).

If you need to restart the UI, run the following.

Ubuntu users who are using the Metrics UI Docker image:

```bash
docker restart mui
```

Wallaroo in Docker and Wallaroo in Vagrant users:

```bash
metrics_reporter_ui restart
```

When it's time to stop the UI, run the following.

Ubuntu users who are using the Metrics UI Docker image:

```bash
docker stop mui
```

Wallaroo in Docker and Wallaroo in Vagrant users:

```bash
metrics_reporter_ui stop
```

If you need to start the UI after stopping it, run the following.

Ubuntu users who are using the Metrics UI Docker image:

```bash
docker start mui
```

Wallaroo in Docker and Wallaroo in Vagrant users:

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

MacOS: Docker compose is already included as part of Docker for Mac.


**NOTE:** You might need to run with sudo depending on how you set up Docker.

Clone local-kafka-cluster project and run it:

```bash
cd /tmp
git clone https://github.com/effata/local-kafka-cluster
cd local-kafka-cluster
./cluster up 1 # change 1 to however many brokers are desired to be started
docker exec -it local_kafka_1_1 /kafka/bin/kafka-topics.sh --zookeeper \
  zookeeper:2181 --create --partitions 4 --topic test-in --replication-factor \
  1 # to create a test-in topic; change arguments as desired
docker exec -it local_kafka_1_1 /kafka/bin/kafka-topics.sh --zookeeper \
  zookeeper:2181 --create --partitions 4 --topic test-out --replication-factor \
  1 # to create a test-out topic; change arguments as desired
```

**Note:** The `./cluster up 1` command outputs `Host IP used for Kafka Brokers is <YOUR_HOST_IP>`. You will need to use this IP address for the `kafka_source_brokers` and `kafka_sink_brokers` arguments when starting `machida` within Docker in order to communicate with the cluster running on your host machine.

#### Set up a listener to monitor the Kafka topic to which you would the application to publish results. We usually use `kafkacat`.

`kafkacat` can be installed via:

```bash
docker pull ryane/kafkacat
```

##### Run `kafkacat` from Docker

To run `kafkacat` to listen to the `test-out` topic via Docker:

**NOTE:** You will need to replace the IP address for the `-b` option with the one provided by `./cluster up 1` command in Shell 1.

```bash
docker run --rm -it ryane/kafkacat -C -b 127.0.0.1:9092 -t test-out -q
```

### Shell 3: Celsius-kafka

Set `PATH` to refer to the directory that contains the `machida` executable. Set `PYTHONPATH` to refer to the current directory (where `celsius.py` is) and the `machida` directory (where `wallaroo.py` is). Assuming you installed Wallaroo according to the tutorial instructions you would do:

**Note:** If running in Docker, the `PATH` and `PYTHONPATH` variables are pre-set for you to include the necessary directories to run this example.

```bash
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build:$HOME/wallaroo-tutorial/wallaroo/utils/cluster_shutdown"
export PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo-tutorial/wallaroo/machida"
```

Run `machida` with `--application-module celsius`:

```bash
machida --application-module celsius \
  --kafka_source_topic test-in --kafka_source_brokers 127.0.0.1:9092 \
  --kafka_sink_topic test-out --kafka_sink_brokers 127.0.0.1:9092 \
  --kafka_sink_max_message_size 100000 --kafka_sink_max_produce_buffer_ms 10 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:12500 --data 127.0.0.1:12501 \
  --external 127.0.0.1:5050 --cluster-initializer --ponythreads=1 \
  --ponynoblock
```

`kafka_sink_max_message_size` controls maximum size of message sent to kafka in a single produce request. Kafka will return errors if this is bigger than server is configured to accept.

`kafka_sink_max_produce_buffer_ms` controls maximum time (in ms) to buffer messages before sending to kafka. Either don't specify it or set it to `0` to disable batching on produce.

### Shell 4: Sender

Send data into Kafka. Again, we use `kafakcat`.

Run the following and then type at least 4 characters on each line and hit enter to send in data (only first 4 characters are used/interpreted as a float; the application will throw an error and possibly segfault if less than 4 characters are sent in):

**NOTE:** You will need to replace the IP address for the `-b` option with the one provided by `./cluster up 1` command in Shell 1.

```bash
docker run --rm -it ryane/kafkacat -P -b 127.0.0.1:9092 -t test-in
```

Note: You can use `ctrl-d` to exit `kafkacat`

## Shell 5: Shutdown

Set `PATH` to refer to the directory that contains the `cluster_shutdown` executable. Assuming you installed Wallaroo  according to the tutorial instructions you would do:

**Note:** If running in Docker, the `PATH` variable is pre-set for you to include the necessary directories to run this example.

```bash
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build:$HOME/wallaroo-tutorial/wallaroo/giles/sender:$HOME/wallaroo-tutorial/wallaroo/utils/cluster_shutdown"
```
You can shut down the Wallaroo cluster with this command:

```bash
cluster_shutdown 127.0.0.1:5050
```

You can shut down the kafkacat producer by pressing Ctrl-d from its shell.

You can shut down the kafkacat consumer by pressing Ctrl-c from its shell.

### Stop kafka

NOTE: You might need to run with sudo depending on how you set up Docker.

If you followed the commands earlier to start kafka you can stop it by running:

```bash
cd /tmp/local-kafka-cluster
./cluster down # shut down cluster
```

You can shut down the Metrics UI with the following command.

Ubuntu users who are using the Metrics UI Docker image:

```bash
docker stop mui
```

Wallaroo in Docker and Wallaroo in Vagrant users:

```bash
metrics_reporter_ui stop
```
