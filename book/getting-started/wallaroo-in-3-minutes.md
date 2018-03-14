# Wallaroo in 3 minutes

This section aims to give a hands-on introduction to Wallaroo by walking through the [Celsius](https://github.com/WallarooLabs/wallaroo/tree/master/examples/python/celsius) example application.

## Celsius application

First things first. What is this "Celsius" application? It's a toy example that converts incoming temperatures in Celsius to Fahrenheit. To convert from Celsius to Fahrenheit, one must first multiply by 1.8, then add 32. The application is laid out so that there is one "computation" (more about that later) for the multiplication, and one for the addition.

### Input and Output

The inputs and outputs of the "Celsius" application are binary 32-bits float encoded in the [source message framing protocol](/book/appendix/writing-your-own-feed.md#source-message-framing-protocol). Here's an example message, written as a Python string:

```
"\x00\x00\x00\x04\x42\x48\x00\x00"
```

`\x00\x00\x00\x04` -- four bytes representing the number of bytes in the payload

`\x42\x48\x00\x00` -- four bytes representing the 32-bit float `50.0`

### celsius.py

First, we need to import struct which is used for encoding and decoding messages to the outside world (anything that connects to our application), and the Wallaroo support library.

```python
import struct
import wallaroo
```

#### Create the topology

Next, we define a module-level function called `application_setup` in our module that creates the structure of the application. We call this the "topology".

```python
def application_setup(args):
```

We specify our inbound and outbound connections, which are specified by the user with the `--in` and `--out` command line arguments. Luckily, wallaroo offers a helper to deal with this.

```python
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]
```

Now let's create our `ApplicationBuilder`. This is the object that will construct the application definition and communicate it to the Wallaroo engine. Let's call our application "Celsius to Fahrenheit".

```python
    ab = wallaroo.ApplicationBuilder("Celsius to Fahrenheit")
```

The next step is to create and populate a "pipeline". This is the definition of the computations that we wish to create and their ordering. The first call creates the pipeline and specifies the TCP "Source" information. This includes the input address (host and port), and the object that will perform the decoding of messages from the "wire format".

```python
    ab.new_pipeline("Celsius Conversion",
                    wallaroo.TCPSourceConfig(in_host, in_port, Decoder()))
```

Now we send everything to our `Multiply` computation (multiply by 1.8), after which comes the `Add` computation (add 32).

```python
    ab.to(Multiply)
    ab.to(Add)
```

After this, we must specify where our outgoing messages are sent. To do this, we specify a TCP "sink", which needs to know about the outgoing address and the object responsible for encoding the messages to the outgoing wire format.

```python
    ab.to_sink(wallaroo.TCPSinkConfig(out_host, out_port, Encoder()))
```

Now we are ready to finalize and build our application topology.

```python
    return ab.build()
```

#### Decoder

We need to create a `Decoder` class, which takes incoming wire-format messages and transforms them to objects that we want to handle internally to our application and pass as input messages. In this case, the message object is the simplest possible: a `float`. A `Decoder` must have three functions:
 - `header_length` to define the size of the wire header. This is used to then determine the size of the "payload", and is usually a fixed number.
 - `payload_length` to obtain the size of the payload contents of each message. This usually interprets the bytes that were in the header (in this case 4).
 - `decode` to convert the payload to the object we want to use.

```python
class Decoder(object):


    def header_length(self):
        return 4

    def payload_length(self, bs):
        return struct.unpack(">I", bs)[0]

    def decode(self, bs):
        return struct.unpack('>f', bs)[0]
```

#### Computations

We can now define our computations for the application. We previously decided that we would have two: `Multiply` first, and `Add` second. This is reflected in the topology we created earlier. A computation is required to have two member methods:
 - `name` to be able to uniquely identify the computation.
 - `compute` to process any incoming messages and output messages as a result.

Note that computations that come after one another will have to have compatible inputs and outputs. In our case, `Multiply` emits a `float`, which is what `Add` is expecting as input. For now we do not care about type-checking, to keep our example code simple, but remember Wallaroo does not check Python types internally.

`Multiply` multiplies incoming values by 1.8,

```python
class Multiply(object):
    def name(self):
        return "multiply by 1.8"

    def compute(self, data):
        return data * 1.8
```

and `Add` adds 32.

```python
class Add(object):
    def name(self):
        return "add 32"

    def compute(self, data):
        return data + 32
```

#### Encoder

Similarly to the `Decoder`, we need the `Encoder` to be able to write bytes to the output TCP sink. Luckily, converting a float to bytes is quite easy. We just have to add our 4-byte "payload length" header value. An `int` with a value of 4 will do nicely.

```python
class Encoder(object):
    def encode(self, data):
        # data is a float
        return struct.pack('>If', 4, data)
```

## Running Celsius

In order to run the application you will need Machida, Giles Sender, and Giles Receiver. To build them, please see the [Linux](/book/linux-setup.md) or [Mac OS](/book/macos-setup.md) setup instructions.

You will need three separate shells to run this application. Open each shell and go to the `examples/python/celsius` directory.

### Shell 1

Run `nc` to listen for TCP output on `127.0.0.1` port `7002`:

```bash
nc -l 127.0.0.1 7002 > celsius.out
```

### Shell 2

Set `PYTHONPATH` to refer to the current directory (where `celsius.py` is) and the `machida` directory (where `wallaroo.py` is). Set `PATH` to refer to the directory that contains the `machida` executable. Assuming you installed Machida according to the tutorial instructions you would do:

```bash
export PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo-tutorial/wallaroo/machida"
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build"
```

Run `machida` with `--application-module celsius`:

```bash
machida --application-module celsius --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --name worker-name --external 127.0.0.1:5050 --cluster-initializer \
  --ponythreads=1
```

### Shell 3

Send messages:

```bash
../../../giles/sender/sender --host 127.0.0.1:7010 \
  --file data_gen/celsius.msg --batch-size 50 --interval 10_000_000 \
  --messages 1000000 --repeat \
  --ponythreads=1 --binary --msg-size 8
```

## Reading the Output

The output data will be in the file that `nc` is writing to in shell 1. You can read the output data with the following code:

```python
import struct


with open('celsius.out', 'rb') as f:
    while True:
        try:
            print struct.unpack('>If', f.read(12))
        except:
            break
```

## Shutting Down The Cluster

You can shut down the cluster with this command once processing has finished:

```bash
../../../utils/cluster_shutdown/cluster_shutdown 127.0.0.1:5050
```
