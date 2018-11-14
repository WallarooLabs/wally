# Celsius

## About The Application

This is an example of a stateless application that takes a floating point Celsius value over UDP and sends out a floating point Fahrenheit value as text over UDP using connectors.

### UDP Input and Output Using Connectors

This project includes a script called `run_sample` which assists in running both the source and sink connectors, the application, and provides some sample input, and prints the output.

Each input is a floating point number. We start with 0.0 degrees celsius. From there we count upwards until we hit 100 degrees and then shut down the application. We add a 1 second delay between each message for this demonstration.

The output from this application is presented as text that we can print directly to the terminal. So the first processed value should show 35.6.

## Running Celsius

In order to run the application you will need Machida. We provide instructions for building these tools yourself and we provide prebuilt binaries within a Docker container. Please visit our [setup](https://docs.wallaroolabs.com/book/getting-started/choosing-an-installation-option.html) instructions to choose one of these options if you have not already done so.

The script expects machida to be in a specific path so you may need to edit `run_sample` to use the correct path for your machida executable. Also be sure to have the correct PYTHONPATH environment variable (it should include the wallaroo package which is part of machida).

Once that is done, you can run the application within this directory using:

```bash
./run_sample
```

See the documentation on [using connectors](https://docs.wallaroolabs.com/book/python/using-connectors.html) for more information on how this example works.
