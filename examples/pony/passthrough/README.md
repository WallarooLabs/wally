# Passthrough

This is an example application that will passthrough the input messages as-is.

## Prerequisites

- ponyc
- pony-stable
- Wallaroo

See [Wallaroo Environment Setup Instructions](https://docs.wallaroolabs.com/pony-installation/).

## Building

Build passthrough with

```bash
make build-utils-data_receiver build-testing-tools-fixed_length_message_blaster \
    build-examples-pony-passthrough
```

## Input Data

Any framed data is ok, e.g., sending the
`testing/data/market_spread/nbbo/350-symbols_nbbo-fixish.msg`
data using the `testing/tools/fixed_length_message_blaster` utility.

## Running Passthrough

You will need five separate shells to run this application. Open each shell and go to the `examples/pony/passthrough` directory.

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

### Shell 3: Passthrough
Start the application

```bash
./passthrough \
  --source tcp --stage asis --sink tcp \
  --in "InputBlobs"@127.0.0.1:7010 --out 127.0.0.1:7002 --metrics 127.0.0.1:5001 \
  --control 127.0.0.1:12500 --data 127.0.0.1:12501 --external 127.0.0.1:5050 \
  --cluster-initializer --ponynoblock --ponythreads=1
```

### Shell 4: Sender

Start a sender

```bash
./testing/tools/fixed_length_message_blaster/fixed_length_message_blaster \
  --host 127.0.0.1:7010 \
  --file ./testing/data/market_spread/orders/350-symbols_orders-fixish.msg \
  --batch-size 450 --msg-size 57 \
  --ponythreads=1 --ponypinasio --ponypin --ponynoblock
```

## Shutdown

### Shell 5: Shutdown

You can shut down the cluster with this command at any time:

```bash
cluster_shutdown 127.0.0.1:5050
```

You can shut down `fixed_length_message_blaster` and Data Receiver by pressing Ctrl-c from their respective shells.

You can shut down the Metrics UI with the following command:

```bash
metrics_reporter_ui stop
```
