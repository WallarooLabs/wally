# Run a Wallaroo Application

In this section, we're going to run an example Wallaroo application. By the time you are finished, you'll have validated that your environment is set up and working correctly.

There's a couple Wallaroo support applications that you'll be interacting with for the first time:

- Our Metrics UI that allows you to monitor the performance and health of your applications.
- Giles receiver is designed to capture TCP output from Wallaroo applications.
- Giles sender is used to send test data into Wallaroo applications over TCP.

You're going to setup our "Celsius to Fahrenheit" example. Giles sender will be used to pump data into the application. Giles receiver will receive the output and our Metrics UI will be running so you can observe the overall performance.

Let's get started!

## Start the Metrics UI

To start the Metrics UI run:

```bash
docker run -d --name mui -p 0.0.0.0:4000:4000 -p 0.0.0.0:5001:5001 \
  sendence/wallaroo-metrics-ui:pre-0.0.1
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

## Run Giles Receiver

We need to set up a data receiver where we can send the output stream from our application:

```bash
cd ~/wallaroo-tutorial/wallaroo/giles/receiver
stable env ponyc
```

This will create a binary called `receiver`

You will now be able to start the `receiver` with the following command:

```bash
./receiver -l 127.0.0.1:5555 --ponythreads=1
```

You should see the `Listening for data` that indicates that Giles receiver is running.

## Compile the Celsius Conversion App

We'll be running the [celsius conversion application](https://github.com/Sendence/wallaroo/tree/master/book/examples/pony/celsius/celsius.pony).

```bash
cd ~/wallaroo-tutorial/wallaroo/book/examples/pony/celsius
```

Now compile the Celsius Conversion app:

```bash
stable env ponyc
```

This will create a binary called `celsius`.

## Run the Celsius Conversion App

Now that we have our Celsius Conversion application compiled, and the metrics UI and something it can send output to up and running, we can run the application itself by executing the following command from our original terminal:

```bash
./celsius -i 127.0.0.1:7000 -o 127.0.0.1:5555 -m 127.0.0.1:5001 \
-c 127.0.0.1:6000 -d 127.0.0.1:6001 --ponythreads=1
```

This tells Wallaroo that it should listen on port 7000 for incoming data, write outgoing data to port 5555, and send metrics data to port 5001.

## Let's Get Some Data: Running Giles Sender

### Generating Some Data

A data generator is bundled with the application. It needs to be built:

```bash
cd data_gen
ponyc
```

Then you can generate a file with a fixed number of psuedo-random votes:

```
./data_gen --message-count 10000
```

This will create a `celsius.msg` file in your current working directory.

### Sending Data

Giles Sender is used to mimic the behavior of an incoming data source.

Open a new terminal and run the following to compile the sender:

```bash
cd ~/wallaroo-tutorial/wallaroo/giles/sender
stable env ponyc
```

This will create a binary called `sender`

You will now be able to start the `sender` with the following command:

```bash
./sender -h 127.0.0.1:7000 -m 100000 -y -s 300 \
  -f ~/wallaroo-tutorial/wallaroo/book/examples/pony/celsius/data_gen/celsius.msg \
  -r -w -g 8 --ponythreads=1
```

If the sender is working correctly, you should see `Connected` printed to the screen. If you see that, you can be assured that we are now sending data into our example application.

## Check Out Some Metrics

### First Look

Once the sender has successfully connected, if you [visit the Metrics UI](http://localhost:4000) the landing page should show you that the Celsius Conversion application has successfully connected.

![Landing Page](/book/metrics/images/landing-page.png)

If your landing page resembles the one above, the Celsius Conversion application has successfully connected to the Metrics UI.

Now, let's have a look at some metrics. By clicking on the Celsius Conversion App link, you'll be taken to the Application Dashboard page. On this page you should see metric stats for the following:

- a single pipeline: `Celsius Conversion`
- a single worker: `Initializer`
- three computations: `Add32`, `Decode Time in TCP Source`, `Multiply by 1.8`

![Application Dashboard Page](/book/metrics/images/application-dashboard-page.png)

You'll see the metric stats update as data continues to be processed in our application.

You can then click into one of the elements within a category, to get to a detailed metrics page for that element. If we were to click into the `Add32` computation, we'll be taken to this page:

![Computation Detailed Metrics page](/book/metrics/images/computation-detailed-metrics-page.png)

Feel free to click around and get a feel for how the Metrics UI is setup and how it is used to monitor a running Wallaroo application. If you'd like a deeper dive into the Metrics UI, have a look at our [Monitoring Metrics with the Monitoring Hub](/book/metrics/metrics-ui.md) section.
