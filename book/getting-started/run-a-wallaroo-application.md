# Run a Wallaroo Application

In this section, we're going to run an example Wallaroo application. By the time you are finished, you'll have validated that your environment is set up and working correctly.

There are a few Wallaroo support applications that you'll be interacting with for the first time:

- Our Metrics UI that allows you to monitor the performance and health of your applications.
- Giles receiver is designed to capture TCP output from Wallaroo applications.
- Giles sender is used to send test data into Wallaroo applications over TCP.
- Machida, our program for running Wallaroo Python applications.

You're going to set up our "Celsius to Fahrenheit" example application. Giles sender will be used to pump data into the application. Giles receiver will receive the output, and our Metrics UI will be running so you can observe the overall performance.

The Metrics UI process will be run in the background via Docker.  The other three processes (receiver, sender, and Wallaroo) will run in the foreground.  We recommend that you run each process in a separate terminal.

Let's get started!

## Terminal 1, Start the Metrics UI

NOTE: You might need to run with sudo depending on how you set up Docker.

To start the Metrics UI run:

```bash
docker run -d --name mui -p 0.0.0.0:4000:4000 -p 0.0.0.0:5001:5001 \
  wallaroo-labs-docker-wallaroolabs.bintray.io/release/metrics_ui:0.3.2
```

You can verify it started up correctly by visiting [http://localhost:4000](http://localhost:4000).

If you need to restart the UI, run:

```bash
docker restart mui
```

When it's time to stop the UI, run:

```bash
docker stop mui
```

If you need to start the UI after stopping it, run:

```bash
docker start mui
```

## Terminal 2, Run Giles Receiver

We'll use Giles Receiver to listen for data from our Wallaroo application.

```bash
cd ~/wallaroo-tutorial/wallaroo/giles/receiver
./receiver --listen 127.0.0.1:5555 --no-write --ponythreads=1 --ponynoblock
```

You should see the `Listening for data` that indicates that Giles receiver is running.

## Terminal 3, Run the "Celsius to Fahrenheit" Application

First, we will need to set up the `PYTHONPATH` environment variable. Machida needs to be able to find the `wallaroo` Python module, which is in a file called `wallaroo.py` in the `machida` directory. It also needs to be able to find the module that defines the application. In order to do that, set and export the `PYTHONPATH` environment variable like this:

```bash
export PYTHONPATH="$HOME/wallaroo-tutorial/wallaroo/machida:$HOME/wallaroo-tutorial/wallaroo/examples/python/celsius"
```

Now that we have Machida set up to run the "Celsius to Fahrenheit" application, and the metrics UI and something it can send output to up and running, we can run the application itself by executing the following command:

```bash
cd ~/wallaroo-tutorial/wallaroo/machida
./build/machida --application-module celsius --in 127.0.0.1:7000 \
  --out 127.0.0.1:5555 --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 \
  --data 127.0.0.1:6001 --name worker-name --external 127.0.0.1:5050 \
  --cluster-initializer --ponythreads=1 --ponynoblock
```

This tells the "Celsius to Fahrenheit" application that it should listen on port `7000` for incoming data, write outgoing data to port `5555`, and send metrics data to port `5001`.

## Terminal 4

### Sending Data with Giles Sender

We will be sending in 25,000,000 messages using a pre-generated data file. The data file will be repeatedly sent via Giles Sender until we reach 25,000,000 messages.

You will now be able to start the `sender` with the following command:

```bash
cd ~/wallaroo-tutorial/wallaroo/giles/sender
./sender --host 127.0.0.1:7000 --messages 25000000 --binary --batch-size 300 \
  --repeat --no-write --msg-size 8 --ponythreads=1 --ponynoblock \
  --file ~/wallaroo-tutorial/wallaroo/examples/python/celsius/celsius.msg
```

If the sender is working correctly, you should see `Connected` printed to the screen. If you see that, you can be assured that we are now sending data into our example application.

## Check Out Some Metrics

### First Look

Once the sender has successfully connected, if you [visit the Metrics UI](http://localhost:4000) the landing page should show you that the "Celsius to Fahrenheit" application has successfully connected.

![Landing Page](/book/metrics/images/landing-page.png)

If your landing page resembles the one above, the "Celsius to Fahrenheit" application has successfully connected to the Metrics UI.

Now, let's have a look at some metrics. By clicking on the "Celsius to Fahrenheit" link, you'll be taken to the "Application Dashboard" page. On this page you should see metric stats for the following:

- a single pipeline: `Celsius Conversion`
- a single worker: `Initializer`
- three computations: `Add32`, `Decode Time in TCP Source`, `Multiply by 1.8`

![Application Dashboard Page](/book/metrics/images/application-dashboard-page.png)

You'll see the metric stats update as data continues to be processed in our application.

You can then click into one of the elements within a category, to get to a detailed metrics page for that element. If we were to click into the `Add32` computation, we'll be taken to this page:

![Computation Detailed Metrics page](/book/metrics/images/computation-detailed-metrics-page.png)

Feel free to click around and get a feel for how the Metrics UI is setup and how it is used to monitor a running Wallaroo application. If you'd like a deeper dive into the Metrics UI, have a look at our [Monitoring Metrics with the Monitoring Hub](/book/metrics/metrics-ui.md) section.

## Shutdown

### Terminal 5, Cluster Shutdown

You can shut down the cluster with this command once processing has finished:

```bash
cd ~/wallaroo-tutorial/wallaroo/utils/cluster_shutdown
./cluster_shutdown 127.0.0.1:5050
```

You can shut down Giles Sender and Giles Receiver by pressing Ctrl-c from their respective shells.

You can shut down the Metrics UI with the following command:

```bash
docker stop mui
```
