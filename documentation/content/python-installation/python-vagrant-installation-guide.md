---
title: "Installing with Vagrant"
menu:
  docs:
    parent: "pyinstallation"
    weight: 3
toc: true
---
To get you up and running quickly with Wallaroo, we have provided a Vagrantfile which includes Wallaroo and related tools needed to run and modify a few example applications. We should warn that this Vagrantfile was created with the intent of getting users started quickly with Wallaroo and is not intended to be suitable for production. Wallaroo in Vagrant runs on Ubuntu Linux Xenial.

## Set up Environment for the Wallaroo Tutorial

### Linux and MacOS

If you haven't already done so, create a directory called `~/wallaroo-tutorial` and navigate there by running:

```bash
cd ~/
mkdir ~/wallaroo-tutorial
cd ~/wallaroo-tutorial
```

This will be our base directory in what follows. Create a directory for the current Wallaroo version and download the Wallaroo Vagrantfile:

```bash
mkdir wallaroo-{{% wallaroo-version %}}
cd wallaroo-{{% wallaroo-version %}}
mkdir vagrant
cd vagrant
curl -o Vagrantfile -J -L \
  https://raw.githubusercontent.com/WallarooLabs/wallaroo/{{% wallaroo-version %}}/vagrant/Vagrantfile
```

### Windows via Powershell

**Note:** This section of the guide assumes you are using Powershell.

If you haven't already done so, create a directory called `~/wallaroo-tutorial` and navigate there by running:

```bash
cd ~/
mkdir ~/wallaroo-tutorial
cd ~/wallaroo-tutorial
```

This will be our base directory in what follows. Create a directory for the current Wallaroo version and download the Wallaroo Vagrantfile:

```bash
mkdir wallaroo-{{% wallaroo-version %}}
cd wallaroo-{{% wallaroo-version %}}
mkdir vagrant
cd vagrant
Invoke-WebRequest -OutFile Vagrantfile `
  https://raw.githubusercontent.com/WallarooLabs/wallaroo/{{% wallaroo-version %}}/vagrant/Vagrantfile
```

## Installing VirtualBox

The Wallaroo Vagrant environment is dependent on the default provider, [VirtualBox](https://www.vagrantup.com/docs/virtualbox/). To install VirtualBox, download a installer or package for your OS [here](https://www.virtualbox.org/wiki/Downloads). Linux users can also use `apt-get` as documented below.

### Linux

```bash
sudo apt-get install virtualbox
```

## Installing Vagrant

### Linux Ubuntu, MacOS, and Windows

Download links for the appropriate installer or package for each supported OS can be found on the [Vagrant downloads page](https://www.vagrantup.com/downloads.html).

## Provision the Vagrant Box

Provisioning should take about 10 to 15 minutes. When it finishes, you will have a complete Wallaroo development environment. You won’t have to go through the provisioning process again unless you destroy the Wallaroo environment by running `vagrant destroy`.

To provision, run the following commands:

```bash
cd ~/wallaroo-tutorial/wallaroo-{{% wallaroo-version %}}/vagrant
vagrant up
```

### What's Included in the Wallaroo Vagrant Box

* **Machida**: runs Wallaroo Python applications for Python 2.7.

* **Machida3**: runs Wallaroo Python applications for Python 3.5+.

* **Giles Sender**: supplies data to Wallaroo applications over TCP.

* **Cluster Shutdown tool**: notifies the cluster to shut down cleanly.

* **Metrics UI**: receives and displays metrics for running Wallaroo applications.

* **Wallaroo Source Code**: full Wallaroo source code is provided, including Python example applications.

### Shutdown the Vagrant Box

You can shut down the Vagrant Box by running the following on your host machine:

```bash
cd ~/wallaroo-tutorial/wallaroo-{{% wallaroo-version %}}/vagrant
vagrant halt
```

### Restart the Vagrant Box

If you need to restart the Vagrant Box you can run the following command from the same directory:

```bash
vagrant up
```

Awesome! All set. Time to try running your first Wallaroo application in Vagrant.

## Validate your installation

In this section, we're going to run an example Wallaroo application. By the time you are finished, you'll have validated that your environment is set up and working correctly.

There are a few Wallaroo support applications that you'll be interacting with for the first time:

- Our Metrics UI allows you to monitor the performance and health of your applications.
- Data receiver is designed to capture TCP output from Wallaroo applications.
- Machida or Machida3, our programs for running Wallaroo Python 2.7 and Python 3.5+ applications, respectively.

You're going to set up our "Alerts" example application. We will use an internal generator source to generate simulated inputs into the system. The data receiver will receive the output, and our Metrics UI will be running so you can observe the overall performance.

The Metrics UI process will be run in the background. The other two processes (data_receiver and Wallaroo) will run in the foreground. We recommend that you run each process in a separate terminal.

For each shell you're expected to setup, you'd have to run the following to access the Vagrant box:

```bash
cd ~/wallaroo-tutorial/wallaroo-{{< wallaroo-version >}}/vagrant
vagrant ssh
```

Let's get started!

Since Wallaroo is a distributed application, its components need to run separately, and concurrently, so that they may connect to one another to form the application cluster. For this example, you will need 4 separate terminal shells to run the metrics UI, run a sink, run the "Alerts" application, and eventually, to send a cluster shutdown command.

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
export PYTHONPATH="$HOME/wallaroo-tutorial/wallaroo-{{% wallaroo-version %}}/examples/python/alerts_stateless:$PYTHONPATH"
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
