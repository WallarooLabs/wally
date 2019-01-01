# Alerts (stateless)

## About The Application

This is an example of a stateless application that takes a transaction
and sends an alert if its value is above or below a threshold.

### Input

For simplicity, we use a generator source that creates a stream of transaction
objects.

### Processing

We sum transaction totals in sliding windows, and when they're triggered, check if the sum is either above or below a thershold, at which point we send an alert.

### Output

Alerts will output messages that are string representations of triggered
alerts. 

## Running Alerts

You will need four separate shells to run this application (please see [starting a new shell](https://docs.wallaroolabs.com/book/getting-started/starting-a-new-shell.html) for details depending on your installation choice). Open each shell and go to the `examples/pony/alerts_windowed` directory.

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

### Shell 2: Data Receiver

Run Data Receiver to listen for TCP output on `127.0.0.1` port `7002`:

```bash
data_receiver --ponythreads=1 --ponynoblock --listen 127.0.0.1:7002
```

### Shell 3: Alerts

Run `machida` with `--application-module alerts`:

```bash
alerts_stateless --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --name worker-name --external 127.0.0.1:5050 --cluster-initializer \
  --ponynoblock
```

Because we're using a generator source, Wallaroo will start processing the input stream as soon as the application connects to the sink and finishes
initialization.

## Shell 4: Shutdown

You can shut down the cluster with this command at any time:

```bash
cluster_shutdown 127.0.0.1:5050
```

You can shut down Data Receiver by pressing `Ctrl-c` from its shell.

You can shut down the Metrics UI with the following command.

```bash
metrics_reporter_ui stop
```
