# Celsius

## About The Application

This is an example of a stateless Python application that takes a floating point Celsius value from Kafka and sends out a floating point Fahrenheit value to Kafka.

### Input and Output

The inputs and outputs of the "Celsius Kafka" application are binary 32-bit floats. Here's an example message, written as a Python string:

```
"\x42\x48\x00\x00"
```

`\x42\x48\x00\x00` -- four bytes representing the 32-bit float `50.0`


### Processing

The `Decoder`'s `decode(...)` method creates a float from the value represented by the payload. The float value is then sent to the `Multiply` computation where it is multiplied by `1.8`, and the result of that computation is sent to the `Add` computation where `32` is added to it. The resulting float is then sent to the `Encoder`, which converts it to an outgoing sequence of bytes.

## Running Celsius Kafka

In order to run the application you will need Machida.

You will also need access to a Kafka cluster. This example assumes that there is a Kafka broker listening on port `9092` on `127.0.0.1`.

You will need three separate shells to run this application. Open each shell and go to the `examples/python/celsius-kafka` directory.

### Shell 1

Set up a listener to monitor the Kafka topic to which you would the application to publish results. We usually use `kafkacat`.

### Shell 2

Set `PYTHONPATH` to refer to the current directory (where `celsius.py` is) and the `machida` directory (where `wallaroo.py` is). Set `PATH` to refer to the directory that contains the `machida` executable. Assuming you installed Machida according to the tutorial instructions you would do:

```bash
export PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo-tutorial/wallaroo/machida"
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build"
```

Run `machida` with `--application-module celsius`:

```bash
./machida --application-module celsius \
  --kafka_source_topic test-in --kafka_source_brokers 127.0.0.1:9092 \
  --kafka_sink_topic test-out --kafka_sink_brokers 127.0.0.1:9092 \
  --kafka_sink_max_message_size 100000 --kafka_sink_max_produce_buffer_ms 10 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:12500 --data 127.0.0.1:12501 \
  --cluster-initializer --ponythreads=1
```

`kafka_sink_max_message_size` controls maximum size of message sent to kafka in a single produce request. Kafka will return errors if this is bigger than server is configured to accept.

`kafka_sink_max_produce_buffer_ms` controls maximum time (in ms) to buffer messages before sending to kafka. Either don't specify it or set it to `0` to disable batching on produce.

### Shell 3

Send data into Kafka. Again, we use `kafakcat`.
