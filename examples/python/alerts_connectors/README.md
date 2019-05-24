# Alerts (stateful)

## About The Application

This is an example of a stateless application that takes a transaction over UDP and sends out an alert if the total is above or below a threshold over UDP using connectors.

### UDP Input and Output Using Connectors

This project includes a script called `run_sample` which assists in running both the source and sink connectors, the application, and provides some sample input, and prints the output.

Each input is a transaction object, containing the user and the transaction amount.

Alerts will output messages that are string representations of triggered alerts.

## Running Alerts

In order to run the application you will need Machida. We provide instructions for building these tools yourself and we provide prebuilt binaries within a Docker container. Please visit our [setup](https://docs.wallaroolabs.com/python-installation/) instructions to choose one of these options if you have not already done so.

The script expects machida to be in a specific path so you may need to edit `run_sample` to use the correct path for your machida executable. Also be sure to have the correct PYTHONPATH environment variable (it should include the wallaroo package which is part of machida).

Once that is done, you can run the application within this directory using:

```bash
./run_sample
```

See the documentation on [using connectors](https://docs.wallaroolabs.com/python-tutorial/using-connectors/) for more information on how this example works.
