---
title: "Using Connectors as Sources & Sinks"
menu:
  docs:
    parent: "pytutorial"
    weight: 1
toc: true
---
This is a preview release of Wallaroo's connectors feature that allows full customization of sources and sinks. These sources and sinks can be integrated into Wallaroo using libraries you're already familiar with in Python. A number of built-in connectors offer a quick way to get started and hook up common stream types and they're all available for easy customization.

Care has been taken to keep the API simple and the runtime assumptions unobtrusive so it's easy to hook up the library to existing code. Read down below for more information on how this works. As this is still a preview release, we are looking for early feedback and would love to hear from you. You can connect with us by emailing [hello@wallaroolabs.com](mailto:hello@wallaroolabs.com).

Connectors are comprised of two parts. First is the entry in your application builder which explains how encoding and decoding of the content works as well as giving each connector instance a name and direction of flow (source or sink). Second is the script which is a local process which runs side-by-side with Wallaroo. We'll look at each part in turn in the sections below.

## Using a Connector in Your Application

In your application module's `application_setup` function, the application builder returns a description of your application in terms of pipelines. Connectors tap into this by allowing the declaration of source and sink connectors and wiring these up by name in your pipeline definitions.

Here is an example of what this looks like:

```python
def application_setup(args):
    ab = wallaroo.ApplicationBuilder("Celsius to Fahrenheit")

    ab.source_connector("celsius_feed",
        encoder=encode_feed,
        decoder=decode_feed)

    ab.sink_connector("fahrenheit_conversion",
        encoder=encode_conversion,
        decoder=decode_conversion)

    ab.new_pipeline("Celsius Conversion", "celsius_feed")
    ab.to(multiply)
    ab.to(add)
    ab.to_sink("fahrenheit_conversion")
    return ab.build()
```

You can follow along in this example by going to [github](https://github.com/WallarooLabs/wallaroo/tree/{{< wallaroo-version >}}/examples/python/celsius_connectors/).

We have introduced two new application builder methods for declaring connectors: `source_connector` and `sink_connector`. These allow you to describe both ends of the connection so the connector script can encode or decode data in a way that's compatible with your application's worker code. Keeping these in one place helps ensure that it's easy to keep them in sync.

In this example we can look at the celsius feed's encoder and decoder functions:

```python
@wallaroo.experimental.stream_message_encoder
def encode_feed(data):
    return data

@wallaroo.experimental.stream_message_decoder
def decode_feed(data):
    return struct.unpack(">f", data)[0]
```

Here we've defined two functions and use `wallaroo.experimental.stream_message_encoder` and `wallaroo.experimental.stream_message_decoder` as decorators. These decorators will handle framing and delivery of your data, so all you need to ensure is that the bytes represent the single message you want to deliver.

You might ask why the example's encoder function definition is only returning the data. In this case, the example is receiving data that's already a packed floating point number so there is no need to reencode it. This allows the encoder to pass along data as-is when it's already in the correct format.

Returning to the application setup code, we should look at the pipeline definition to understand how all of this comes together. First is the `new_pipeline` call:

```python
ab.new_pipeline("Celsius Conversion", "celsius_feed")
```

Instead of using something like the `wallaroo.TCPSourceConfig` instance that we might have used before (if not, we explain about how this works in the [details](/book/python/api.md#tcpsource) chapter) for a basic TCP source stream, we now use the name of the connector. This must match the type of connector; in this case, new_pipeline expects a source, so we should declare `"celsius_feed"` using `source_connector`.

Likewise, our sink has adopted a named connector:

```python
ab.to_sink("fahrenheit_conversion")
```

This matches up with our call to `sink_connector` and it has its own encoder and decoder functions as well.

Notice how we don't couple the specifics of the medium used by the connector and instead focus on how we interpret incoming messages in terms of their serialization. This allows applications to evolve and mix their infrastructure over time.

## Running Connector Scripts

To run an application that makes use of these connectors we'll need to understand how the connector scripts work. Wallaroo includes a [library of connectors](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/connectors/) to help get you started. We'll look at `udp_source` and `udp_sink` as used in the example introduced above.

These included connectors are self-contained Python scripts. Some of them may expect a related Python library to be installed and available for import but our example uses the UDP facilities provided for by Python's standard library. Be sure that the Python path is set up to include the Wallaroo library.

If we run one of these scripts we'll see there are some required arguments listed. The first one should be familiar. `--application-module` is the same as the one seen when running a Wallaroo worker (you can review these command line parameters in the [Running Wallaroo](/book/running-wallaroo/running-wallaroo.md) section). Providing this argument allows the script to autodetect most of the connector settings by reading the same application description that the Wallaroo application worker runs with.

The application module is not quite enough for the script to know what settings to use when connecting to Wallaroo. Since the application may have more than one connector, the `--connector` argument is required for disambiguating which connector in the application setup this script is running as. With this passed as an argument, we can autodetect the most common settings.

Many connector scripts will have their own additional arguments, some may be required and others may be optional. In this case we have two, the host and port. These argument names prefix the connector name to ensure that conflicting argument names do not cause problems. For example, you should be able to pass all your Wallaroo arguments in without conflict.

To illustrate this, let's look at what the `udp_source` command line parameters might look like:

```bash
./wallaroo/connectors/udp_source --application-module celsius \
    --connector celsius_feed \
    --celsius_feed-host 127.0.0.1 \
    --celsius_feed-port 6789
```

In this example, we are running a UDP source for our application which listens to a UDP socket on 127.0.0.1 port 6789 and forwards the data in each packet to Wallaroo as a message.

Since the included connector scripts are self-contained, feel free to copy it over to your application tree to use them directly and make path management a little easier.

## Starting with Prebuilt Connectors

We have a number of [prebuilt connectors](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/connectors/). Here is a short description of each one. These are all written so they can be copied and customized in your application source tree. You're still welcome to run them in place as well.

### Kafka

This connector provides Kafka source and sink support. This uses the [kafka library](https://pypi.org/project/kafka/). Consumer group based sources are supported to allow easier management of your source's progress through a topic.

While Wallaroo already has built-in Kafka support, using the connector allows you to support the use of consumer groups and reuse any logic you might already have around offset management and consumer lifecycles. We're looking for feedback, so if your Kafka use case doesn't seem to fit either option, please let us know at [hello@wallaroolabs.com](mailto:hello@wallaroolabs.com).

### AWS Kinesis

AWS Kinesis is supported via the [boto3 library](https://pypi.org/project/boto3/). This script will expect AWS credentials to be setup as described in their documentation.

### Redis

Redis has many ways to be used as a source and a sink. We've provided two starting points to show how a source and sink can work. The script is very easy to modify and uses the well maintained [redis library](https://pypi.org/project/redis/).

For the source, we show an example using the subscription support offered by Redis pubsub and it's a natural fit for many stream processing applications. Check out `redis_subscriber_source` for [details](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/connectors/redis_subscriber_source).

For the sink, we show that not everything needs to look exactly like a stream to be used with Wallaroo. We use the given hash key in redis and set key-value pairs on that target hash for each key-value pair passed to the sink. This is very handy for those cases that want to keep track of the latest value. See `redis_hash_sink` for [details](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/connectors/redis_hash_sink).

### RabbitMQ

Our RabbitMQ source uses the [pika library](https://pypi.org/project/pika/). We support automatic provisioning of missing queues in our setup code but it's advised that users ensure they provision their broker's exchange with the appropriate type beforehand.

### UDP

Our UDP support uses the Python standard library. To see an example of it in action, check out the [celsius_connectors example](https://github.com/Wallaroo/wallaroo/tree/{{ book.wallaroo_version }}/examples/python/celsius_connectors/).

### AWS S3

This sink is powered by the [boto3 library](https://pypi.org/project/boto3/) and allows key value pairs to be uploaded as named blobs to an S3 bucket.

### Postgres

We offer some starting templates for Postgres integration. These depend on your database schema and so we've left them in the [connectors/templates directory](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/connectors/templates).

As a source we have a very interesting example of how notifiers can turn a regular table into a stream. If you're struggling with finding an efficient way to stream relational data, this might be a good place to start.

On the sink side, we support inserting new records for each sink output. This should be easy to modify to allow more complex database interactions.

If you have a use-case with Postgres and don't feel like our template addresses it. Please let us know at [hello@wallaroolabs.com](mailto:hello@wallaroolabs.com).

## Building Your Own Connectors

While we offer prebuilt connectors and they can be modified, sometimes you might find yourself needing to build a connector from scratch. We'll walk through a source and sink example.

### Custom Source Connector

To build a new source, you need to import `wallaroo.experimental` along with any other runtime requirements you have. Because this is a vanilla Python runtime, you're welcome to organize your code however you like.

When your script starts running, you need to create the proper
connector instance type. In this case we'd like to build a source connector so we'll use this:

```python
connector = wallaroo.experimental.SourceConnector(required_params=[], optional_params=[])
```

For this connector we're not requesting any additional parameters but if we did, it'd be available on the `connector.params` property.

Once we've constructed this and we're ready to connect to Wallaroo to allow data to flow we call `connect`:

```python
connector.connect()
```

We can pass custom `host` and `port` parameters here if the automatically resolved information needs to change. Since we recommend that you run your connector scripts next to the Wallaroo process, the defaults work just fine.

Your script can do any other initialization but once it's running, all you need is a call to `write`:

```python
connector.write("hello world")
```

In this case, the string hello world will be passed to the encoder function specified in the application module. The resulting bytes will then be sent to the local Wallaroo worker and then decoded with the specified decoder function.

### Custom Sink Connector

Building a sink is very similar to a source except that we listen for connections from Wallaroo rather than connect to Wallaroo.

To get started we build an instance of the sink connector:

```python
connector = wallaroo.experimental.SinkConnector(required_params=[], optional_params=[])
```

Once you're ready to accept incoming data you can call `listen`:

```python
connector.listen()
```

When you're ready to read a value, call the `read` method. Usually this can be done in a loop like so:

```python
while True:
    author, message = connector.read()
    print("{} said {}".format(author, message))
```

In this loop we do one read at a time and expect a tuple to be returned by the decoder function that is automatically called for us (as specified in the application_setup for the application).
