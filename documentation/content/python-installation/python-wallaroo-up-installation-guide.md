---
title: "Installing with Wallaroo Up"
menu:
  toc:
    parent: "pyinstallation"
    weight: 4
toc: true
---

## Supported Systems

Wallaroo Up has been tested on:

- Amazon Linux 2
- CentOS 7
- Debian
  - Buster (Testing)
  - Jessie
  - Stretch
- Fedora
  - 27
  - 28
- Oracle Linux 7
- Ubuntu
  - Artful
  - Bionic
  - Trusty
  - Xenial

It should also work on Red Hat Enterprise Linux 7.

## Memory requirements

In order to compile the Wallaroo example applications, your system will need to have approximately 3 GB working memory (this can be RAM or swap). If you don't have enough memory, you are likely to see that the compile process is `Killed` by the OS.

## Download Wallaroo Up script

```bash
curl https://raw.githubusercontent.com/WallarooLabs/wallaroo/{{% wallaroo-version %}}/misc/wallaroo-up.sh -o /tmp/wallaroo-up.sh -J -L
```

## Run the Wallaroo Up script

The `-t python` argument is required for a Python environment installation. The `-p <PATH>` argument is optional and can be used to control where the Wallaroo tutorial is installed into (the default is `~/wallaroo-tutorial`).

The script will require superuser privileges via `sudo` and will throw an error if `sudo` is not available. The script will prompt you prior to making any changes. It can optionally print out the commands it will run.

```bash
bash /tmp/wallaroo-up.sh -t python
```

Follow the prompts to have Wallaroo Up install and configure Wallaroo and its dependencies.

Once Wallaroo Up has finished installing and configuring Wallaroo for your environment, it will also create an `activate` script that can be used to set up the appropriate environment variables.

Awesome! All set. Time to try running your first application.

## Validate your installation

In this section, we're going to run an example Wallaroo application. By the time you are finished, you'll have validated that your environment is set up and working correctly.

There are a few Wallaroo support applications that you'll be interacting with for the first time:

- Our Metrics UI allows you to monitor the performance and health of your applications.
- Data receiver is designed to capture TCP output from Wallaroo applications.
- Machida or Machida3, our programs for running Wallaroo Python 2.7 and Python 3.5+ applications, respectively.

You're going to set up our "Alerts" example application. We will use an internal generator source to generate simulated inputs into the system. Data receiver will receive the output, and our Metrics UI will be running so you can observe the overall performance.

The Metrics UI process will be run in the background. The other two processes (data_receiver and Wallaroo) will run in the foreground. We recommend that you run each process in a separate terminal.

### Starting new shells

For each Shell you're expected to setup, you'd have to run the following to configure the Wallaroo environment:

```bash
cd ~/wallaroo-tutorial/wallaroo-{{% wallaroo-version %}}
source bin/activate
```

This command will set up the environment variables for running Wallaroo Applications.

Let's get started!

Since Wallaroo is a distributed application, its components need to run separately, and concurrently, so that they may connect to one another to form the application cluster. For this example, you will need 4 separate terminal shells to run the metrics UI, run a sink, run the Alerts application, and eventually, to send a cluster shutdown command.

### Shell 1: Start the Metrics UI

To start the Metrics UI run:

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

### Shell 2: Run Data Receiver

We'll use Data Receiver to listen for data from our Wallaroo application.

```bash
data_receiver --listen 127.0.0.1:5555 --no-write --ponythreads=1 --ponynoblock
```

Data Receiver will start up and receive data without creating any output. By default, it prints received data to standard out, but we are giving it the `--no-write` flag which results in no output.

### Shell 3: Run the "Alerts" Application

First, we will need to set up the `PYTHONPATH` environment variable. Machida needs to be able to find the the module that defines the application. In order to do that, set and export the `PYTHONPATH` environment variable like this:

```bash
export PYTHONPATH="$HOME/wallaroo-tutorial/wallaroo-{{% wallaroo-version %}}/examples/python/alerts_stateful:$PYTHONPATH"
```

Now that we have Machida set up to run the "Alerts" application, and the metrics UI and something it can send output to up and running, we can run the application itself by executing the following command (remember to use the `machida3` executable instead of `machida` if you are using Python 3.X):

```bash
machida --application-module alerts \
  --out 127.0.0.1:5555 --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 \
  --data 127.0.0.1:6001 --name worker-name --external 127.0.0.1:5050 \
  --cluster-initializer --ponythreads=1 --ponynoblock
```

This tells the "Alerts" application that it should write outgoing data to port `5555`, and send metrics data to port `5001`.

### Check Out Some Metrics

Once the application has successfully initialized, the internal test generator source will begin simulating inputs into the system. If you [visit the Metrics UI](http://localhost:4000), the landing page should show you that the "Alerts" application has successfully connected.

![Landing Page](/images/metrics/landing-page.png)

If your landing page resembles the one above, the "Alerts" application has successfully connected to the Metrics UI.

Now, let's have a look at some metrics. By clicking on the "Alerts" link, you'll be taken to the "Application Dashboard" page. On this page you should see metric stats for the following:

- a single pipeline: `Alerts`
- a single worker: `Initializer`
- a single computation: `check transaction total`

![Application Dashboard Page](/images/metrics/application-dashboard-page.png)

You'll see the metric stats update as data continues to be processed in our application.

You can then click into one of the elements within a category to get to a detailed metrics page for that element. If we were to click into the `check transaction total` computation, we'll be taken to this page:

![Computation Detailed Metrics page](/images/metrics/computation-detailed-metrics-page.png)

Feel free to click around and get a feel for how the Metrics UI is set up and how it is used to monitor a running Wallaroo application. If you'd like a deeper dive into the Metrics UI, have a look at our [Monitoring Metrics with the Monitoring Hub](/operators-manual/metrics-ui/) section.

### Shell 4: Cluster Shutdown

You can shut down the cluster with this command at any time:

```bash
cluster_shutdown 127.0.0.1:5050
```

You can shut down Data Receiver by pressing Ctrl-c from its shell.

You can shut down the Metrics UI with the following command:

```bash
metrics_reporter_ui stop
```
