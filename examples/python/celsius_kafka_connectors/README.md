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

In order to run the application you will need Machida compiled with resilience, the Wallaroo ALO Kafka Source Connector, the Wallaroo ALO Kafka Sink Connector, and the Cluster Shutdown tool. We provide instructions for building these tools yourself and we provide prebuilt binaries within a Docker container. Please visit our [setup](https://docs.wallaroolabs.com/python-installation/) instructions to choose one of these options if you have not already done so.
If you are using Python 3, replace all instances of `machida` with `machida3` in your commands.

You will also need access to a Kafka cluster.

**NOTE:** If running in Docker, the Kafka cluster and kafkacat should be run from your host and not within the Docker container.

You will need five separate shells to run this application (please see [starting a new shell](https://docs.wallaroolabs.com/python-tutorial/starting-a-new-shell/) for details depending on your installation choice). Open each shell and go to the `examples/python/celsius-kafka` directory.

### Shell 1: Metrics

Start up the Metrics UI if you don't already have it running.

```bash
metrics_reporter_ui start
```

You can verify it started up correctly by visiting [http://localhost:4000](http://localhost:4000).

If you need to restart the UI, run the following.

```bash
metrics_reporter_ui restart
```

When it's time to stop the UI, run the following.

```bash
metrics_reporter_ui stop
```

If you need to start the UI after stopping it, run the following.

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
sleep 1 # allow kafka to start
docker exec -i local_kafka_1_1 /kafka/bin/kafka-topics.sh --zookeeper \
  zookeeper:2181 --create --partitions 1 --topic test-in --replication-factor \
  1 # to create a test-in topic; change arguments as desired
docker exec -i local_kafka_1_1 /kafka/bin/kafka-topics.sh --zookeeper \
  zookeeper:2181 --create --partitions 1 --topic test-out --replication-factor \
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

**NOTE:** If you're running Wallaroo in Docker, you will need to replace the following with `export KAFKA_IP=*IP OUTPUT BY ./cluster up 1 COMMAND*` instead.

```bash
export KAFKA_IP=$(docker inspect local_kafka_1_1 | grep kafka_ip | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
```

To run `kafkacat` to listen to the `test-out` topic via Docker:

```bash
docker run --rm -i --name kafkacatconsumer ryane/kafkacat -C -b ${KAFKA_IP}:9092 -t test-out -q -u
```
### Shell 3: Wallaroo Kafka Sink Connector

Set the Kafka broker IP address:

**NOTE:** If you're running Wallaroo in Docker, you will need to replace the following with `export KAFKA_IP=*IP OUTPUT BY ./cluster up 1 COMMAND*` instead.

```bash
export KAFKA_IP=$(docker inspect local_kafka_1_1 | grep kafka_ip | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
```

Set the `PYTHONPATH` variable to include the necessary libraries:

```bash
export PYTHONPATH="$PYTHONPATH:../../../machida/lib:../../../connectors/experimental:../../../testing/correctness/tests/aloc_sink:."
```

Set the `PATH` variable to include the Kafka Connector Sink script:

```bash
export PATH="$PATH:../../../connectors/experimental"
```

Start the At Least Once Kafka Connector Sink:

```bash
alo_kafka_sink --host 127.0.0.1 --port 7200 \
  --bootstrap_servers ${KAFKA_IP}:9092 \
  --out_path /tmp/messages.out --abort_rule_path rules.out \
  --topic test-out
```
### Shell 4: Celsius Kafka Connectors App

Set the Kafka broker IP address:

**NOTE:** If you're running Wallaroo in Docker, you will need to replace the following with `export KAFKA_IP=*IP OUTPUT BY ./cluster up 1 COMMAND*` instead.

```bash
export KAFKA_IP=$(docker inspect local_kafka_1_1 | grep kafka_ip | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
```

Run `machida` with `--application-module celsius`:

```bash
machida --application-module=celsius --metrics=127.0.0.1:5001 \
  --in=127.0.0.1:7000 --out=127.0.0.1:5555 \
  --control=127.0.0.1:6000 --data=127.0.0.1:6001 \
  --name=initializer --external=127.0.0.1:5050 \
  --cluster-initializer --run-with-resilience \
  --ponythreads=1 --ponynoblock
```

### Shell 5: Wallaroo ALO Kafka Source Connector

Set the `PYTHONPATH` variable to include the necessary libraries:

```bash
export PYTHONPATH="$PYTHONPATH:../../../machida/lib:../../../connectors/experimental:."
```

Set the `PATH` variable to include the Kafka Connector Source script:

```bash
export PATH="$PATH:../../../connectors/experimental"
```

Start the At Least Once Kafka Connector Source:

```bash
alo_kafka_source --host=127.0.0.1 --port=7000 --topic="test-in" \
  --bootstrap_servers=${KAFKA_IP}:9092 \
  --cookie="Dragons-Love-Tacos"
```

### Shell 6: Sender

Send data into Kafka. Again, we use `kafakcat`.

Set the Kafka broker IP address:

**NOTE:** If you're running Wallaroo in Docker, you will need to replace the following with `export KAFKA_IP=*IP OUTPUT BY ./cluster up 1 COMMAND*` instead.

```bash
export KAFKA_IP=$(docker inspect local_kafka_1_1 | grep kafka_ip | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
```

Run the following to send the numbers 1 - 100 as celsius temperatures:

```bash
seq 1 100 | docker run --rm -i --name kafkacatproducer ryane/kafkacat -P -b ${KAFKA_IP}:9092 -t test-in
```

## Shell 5: Shutdown

You can shut down the Wallaroo cluster with this command:

```bash
cluster_shutdown 127.0.0.1:5050
```

You can shut down the kafkacat consumer by pressing Ctrl-c from its shell.

### Stop the Wallaroo ALO Kafka Connector Source, Sink, and kafkacat consumer

You can shut down theese tools by pressing Ctrl-c from the shell each tool was started in.

### Stop kafka

NOTE: You might need to run with sudo depending on how you set up Docker.

If you followed the commands earlier to start kafka you can stop it by running:

```bash
cd /tmp/local-kafka-cluster
./cluster down # shut down cluster
```

### Remove messages files

```bash
rm /tmp/messages.out*
```

You can shut down the Metrics UI with the following command.

```bash
metrics_reporter_ui stop
```
