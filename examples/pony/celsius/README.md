# Celsius

This is an example of a stateless application that takes a floating point Celsius value and sends out a floating point Fahrenheit value.

## Prerequisites

- ponyc
- pony-stable
- Wallaroo

See [Wallaroo Environment Setup Instructions](https://github.com/WallarooLabs/wallaroo/book/getting-started/setup.md).

## Building

Build Celsius with

```bash
make
```

## Generating Data

A data generator is bundled with the application. Use it to generate a file with a fixed number of psuedo-random votes:

```
cd data_gen
./data_gen --message-count 10000
```

This will create a `celsius.msg` file in your current working directory.

## Running Celsius

You will need five separate shells to run this application. Open each shell and go to the `examples/pony/celsius` directory.

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

### Shell 2: Data Receiver

Start a listener

```bash
data_receiver --listen 127.0.0.1:7002 --no-write \
  --ponythreads=1 --ponynoblock
```

### Shell 3: Alphabet
Start the application

```bash
./celsius --in 127.0.0.1:7010 --out 127.0.0.1:7002 --metrics 127.0.0.1:5001 \
  --control 127.0.0.1:12500 --data 127.0.0.1:12501 --external 127.0.0.1:5050 \
  --cluster-initializer --ponynoblock --ponythreads=1
```

### Shell 4: Sender

Start a sender

```bash
cd data_gen
./data_gen --message-count 10000
cd ..
sender --host 127.0.0.1:7010 \
  --file data_gen/celsius.msg \
  --batch-size 5 --interval 100_000_000 --messages 150 --binary \
  --variable-size --repeat --ponythreads=1 --ponynoblock --no-write
```

## Shutdown

### Shell 5: Shutdown

You can shut down the cluster with this command at any time:

```bash
cluster_shutdown 127.0.0.1:5050
```

You can shut down Giles Sender and Data Receiver by pressing Ctrl-c from their respective shells.

You can shut down the Metrics UI with the following command:

```bash
metrics_reporter_ui stop
```
