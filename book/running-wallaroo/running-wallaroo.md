# Running Wallaroo

A Wallaroo application is distributed over one or more Wallaroo processes, which we call "workers". Any Wallaroo cluster will have one worker designated as the "cluster initializer", a temporary role played during cluster initialization. 

Workers communicate with each other over two channels: a control channel and a data channel. They send metrics data over TCP to an external metrics address. And they optionally listen for messages from external systems over an external channel.  

Depending on the type of sources and sinks used in your application, you might need to provide more configuration information.  For example, a TCP source requires a network address so that it can listen for incoming data.  And a TCP sink requires a target address where it can send output data.

In this document, we'll discuss most of the command line arguments that can be passed to a Wallaroo binary.  For a complete list, see [Wallaroo Command Line Options](/book/running-wallaroo/wallaroo-command-line-options.md).

## Single Worker Setup

If you are starting up a Wallaroo cluster with only one worker, then that worker must be configured as the "cluster initializer" by passing the `--cluster-initializer` flag. You must also specify a target address for metrics data using the `--metrics` parameter. And you must specify its control and data addresses via the `--control` and `--data` command line parameters (these will be used if more workers are added to the cluster later). 

If your application uses a TCP source, then you must specify a TCP input address via `--in`. Likewise, if your application uses a TCP sink, then you must specify a TCP output address via `--out`. In what follows, we'll be using the Celsius Converter example app which uses a TCP source and sink (there are versions of this app written in [Go](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/go/celsius) and [Python](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/python/celsius)).

If you are using the Go or Pony APIs, then you will run a binary called `celsius` in order to run the Celsius Converter app. If you are using the Python API, then you will run [Machida](book/python/intro.md), passing in the application name via `--application-module`. And since Machida is single-threaded, you must pass in `--ponythreads 1` (otherwise Machida will exit early).

Putting this all together, to run the Celsius Converter app, you would run the following command:

{% codetabs name="Python", type="py" -%}
machida --application-module celsius --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --cluster-initializer --ponythreads 1
{%- language name="Go", type="go" -%}
celsius --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --cluster-initializer
{%- endcodetabs %}

If you want to be able to send messages to your worker from external systems (for example, to trigger a cluster shutdown using the [Cluster Shutdown tool](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/utils/cluster_shutdown)), then you need to have the worker listen on an "external channel". This is accomplished by providing an address via the `--external` argument.

## Multi-Worker Setup

A Wallaroo application can alo be distributed over multiple Wallaroo workers. This requires that the `clustering` feature flag has been set during build (it is set by default when building via provided Makefiles in the Wallaroo repo). From among our multiple workers, we will have one play the role of initializer via the `--cluster-initializer` flag. We specify the total number of workers at startup (including the initializer) via the `--worker-count` parameter, which we pass to whichever worker we have chosen to be the initializer. We do not pass the worker count to any other workers at startup. As with the single worker case, we also pass the initializer its control and data channel addresses via `--control` and `--data`.

You must provide a name for any worker that's not the initializer via the `--name` argument. Currently, the initializer's name will always be set to `"initializer"`, even if you provide it with a different name. We plan to change this in the future so that you can name the initializer as well.

You need to tell every non-initializer worker which addresses the initializer is listening on for its control channel. This is done via the `--control` argument. We must also specify the metrics target via `--metrics`, just as we did in the single worker case above. And if we are using a TCP source and sink (as in the Celsius Converter app we're using as an example), then we must also pass every worker an `--in` and `--out` argument to specify the source and sink addresses.

You can optionally set the control and data addresses that a non-initializer will listen on by using the `--my-control` and `--my-data` arguments, respectively.

Assuming we are running a two worker cluster on a single machine, we would run the following commands:

{% codetabs name="Python", type="py" -%}
*Worker 1*

machida --application-module celsius --in 127.0.0.1:6000 \
  --out 127.0.0.1:5555 --metrics 127.0.0.1:5001 \
  --control 127.0.0.1:6500 --data 127.0.0.1:6501 --worker-count 2 \
  --cluster-initializer --ponythreads 1

*Worker 2*

machida --application-module celsius --in 127.0.0.1:6000 \
  --out 127.0.0.1:5555 --metrics 127.0.0.1:5001 \
  --control 127.0.0.1:6500 --name Worker2 --ponythreads 1
{%- language name="Go", type="go" -%}
*Worker 1*

celsius --in 127.0.0.1:6000 --out 127.0.0.1:5555 --metrics 127.0.0.1:5001 \
  --control 127.0.0.1:6500 --data 127.0.0.1:6501 --worker-count 2 \
  --cluster-initializer

*Worker 2*

celsius --in 127.0.0.1:6000 --out 127.0.0.1:5555 --metrics 127.0.0.1:5001 \
  --control 127.0.0.1:6500 --name Worker2
{%- endcodetabs %}

Remember that multi-worker runs require that you distribute the same binary to all machines that are involved. Attempting to connect different binaries into a multi-worker cluster will fail.

## Restarting workers

When a cluster is starting up, all members will save information about the cluster to local disk. If a member exits and is restarted, it uses the saved information to reconnect to the running cluster. By default, cluster information is stored in `/tmp`. You can change the directory using the `--resilience-dir` parameter.

Resilience files are based on the name you supply the worker so starting different applications or clusters and reusing names can lead to odd results if you have leftover files in your resilience directory. To avoid any weirdness, you should use our clean shutdown tool (see the next section) or make sure to "manually" clean your resilience directory. For example, if you were using `/tmp/wallaroo` as a resilience directory, you can manually clean it by running `rm -rf /tmp/wallaroo/` to remove all cluster information files.

## Shutting Down a Cluster

Wallaroo comes with a [cluster shutdown tool](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/utils/cluster_shutdown) that can be used to shut down a running cluster. In order to receive a cluster shutdown message, our workers must be listening on an "external channel". We provide an address for this via the `--external` command line argument. For example, to have our cluster initializer create an external channel listening on `127.0.0.1:5050`, we'd start it up with a command like the following:

```bash
celsius --in 127.0.0.1:6000 --out 127.0.0.1:5555 --metrics 127.0.0.1:5001 \
  --control 127.0.0.1:6500 --data 127.0.0.1:6501 --cluster-initializer \
  --external 127.0.0.1:5050
```

Once the cluster is running, we can use the cluster shutdown tool to contact any running worker that's listening on an external channel. If we wanted to contact the worker started with the command above, we'd run:

```
./cluster_shutdown 127.0.0.1:5050
```
