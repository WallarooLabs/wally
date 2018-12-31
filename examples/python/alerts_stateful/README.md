# Alerts (stateful)

## About The Application

This is an example of a stateful application that takes a transaction and updates a running total. It sends an alert if the total is above or below a threshold.

### Input

For simplicity, we use a generator source that creates a stream of transaction
objects.

### Processing

We add the total of each transaction to a running total at a state computation. If that running total is higher than a certain positive threshold, we create a deposit alert. If it's lower than a certain negative threshold, we create a withdrawal alert.

### Output

Alerts will output messages that are string representations of triggered
alerts.

## Running Alerts

In order to run the application you will need Machida, Data Receiver, and the Cluster Shutdown tool. We provide instructions for building these tools yourself and we provide prebuilt binaries within a Docker container. Please visit our [setup](https://docs.wallaroolabs.com/python-installation/) instructions to choose one of these options if you have not already done so.
If you are using Python 3, replace all instances of `machida` with `machida3` in your commands.

You will need four separate shells to run this application (please see [starting a new shell](https://docs.wallaroolabs.com/python-tutorial/starting-a-new-shell/) for details depending on your installation choice). Open each shell and go to the `examples/python/alerts_stateful` directory.

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
machida --application-module alerts --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --name worker-name --external 127.0.0.1:5050 --cluster-initializer \
  --ponythreads=1 --ponynoblock
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
