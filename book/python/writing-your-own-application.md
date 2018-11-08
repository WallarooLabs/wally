# Writing Your Own Wallaroo Python Application

In this section, we will go over the components that are required in order to write a Wallaroo Python application. We will start with the stateless `alerts.py` application from the [examples](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/python/alerts_stateless/) section, then move on to an application that maintains and modifies state and uses partitioning to divide its work.

## A Stateless Application - Alerts

The `alerts.py` application is going to receive transactions as its input stream, check for certain conditions that should trigger alerts, and then send out any triggered alerts to its sink. In order to do this, our application needs to provide the following functions:

* Computation - this is where the input transaction will be checked for a potential alert condition
* Output encoding - how to construct and format the byte stream that will be sent out by the sink

### Computation

Let's start with the computation, because that's the purpose of the application:

```python
@wallaroo.computation(name="check transaction")
def check_transaction(transaction):
    print("compute -> " + transaction.id + ":" + str(transaction.amount))
    if transaction.amount > 1000:
        return DepositAlert(transaction.id, transaction.amount)
    elif transaction.amount < -1000:
        return WithdrawalAlert(transaction.id, transaction.amount)
```

A Computation has no state, so it only needs to define its name, and how to convert input data into output data. In this case, we check whether certain conditions are met in order to decide whether to return a result. Returning nothing means we drop this message on the floor (we're done with it if no alert is needed).

Note that there is a `print` statement in the `compute` method (and in other methods in this document). They are here to help show the user what is happening at different points as the application executes. This is only for demonstration purposes and is not recommended in actual applications.

### Sink Encoder

Next, we are going to define how the output gets constructed for the sink. It is important to remember that Wallaroo sends its output over the network, so data going through the sink needs to be of type `bytes`. In Python2, this is the same as `str`, but in Python3, strings are Unicode, and need to be converted to `bytes`. Luckily, we can use `encode()` to get a `bytes` from a string in both versions:

```python
@wallaroo.encoder
def encode_alert(alert):
    return str(alert).encode()
```

### Source Decoder

For simplicity's sake, we are using an internal test generator source to simulate a stream of inputs into the application. In a real application, you will probably be receiving inputs in a binary format. If so, you need to define a decoder for converting those bytes to your input types. For more on this, please refer to the [Creating A Decoder](/book/appendix/tcp-decoders-and-encoders.md#creating-a-decoder) section.

### Application Setup

So now that we have our computation and output encoding defined, how do we build it all into an application?
For this, two things are needed:
1. An entry point for Wallaroo to create the application. This is the function `application_setup` that you need to define.
2. The actual topology `application_setup` is going to return for Wallaroo to create the application.

An application is constructed of one or more pipelines which can be merged at various points until they converge on one or more sinks. Our alerts application has only one source stream, so we only need to create one (called `transactions`):

```python
gen_source = wallaroo.GenSourceConfig(TransactionsGenerator())
transactions = wallaroo.source("Alerts (stateless)", gen_source)
```

We are using a `GenSource` in order to simulate inputs to the application.

Next, we add the computation stage:

```python
.to(check_transaction)
```

Wallaroo provides a scale-independent API. That means that we try to parallelize work when it is beneficial. Our default is to parallelize stateless computations, which means that there is no guarantee the outputs downstream will arrive in the same order as the inputs. If for some reason you need to guarantee that your inputs maintain their order, then you should precede the call to `to` with a key_by:

```
.key_by(constant_key)
.to(check_transaction)

@wallaroo.key_extractor
def constant_key(input):
    return "constant"
```

We explain `key_by` in more detail and with examples in the next [section](writing-your-own-stateful-application.md). 

Finally, after adding our computation stage, we add the sink, using a `TCPSinkConfig`:

```python
.to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encode_alert)))
```

### The `application_setup` Entry Point

After Wallaroo has loaded the application's python file, it will try to execute its `application_setup()` function. This function is where the stages from above are going to be defined.

```python
def application_setup(args):
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]
    
    gen_source = wallaroo.GenSourceConfig(TransactionsGenerator())
    transactions = wallaroo.source("Alerts", gen_source)

    pipeline = (transactions
        .to(check_transaction)
        .to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encode_alert)))

    return wallaroo.build_application("Alerts", pipeline)
```

Wallaroo provides the convenience functions `tcp_parse_input_addrs` and `tcp_parse_output_addrs` to parse host and port information that is passed on the command line, or the user can supply their own code for getting these values. When using the convenience functions, host/port pairs are represented on the command line as colon-separated values and multiple host/port values are represented by a comma-separated list of host/port values. The functions assume that `--in` is used for input addresses, and `--out` is used for output addresses. For example, this set of command line arguments would specify two input host/port values and one output:

```
--in localhost:7001,localhost:7002 --out localhost:7010
```

Since we are using an internal `GenSource` for our example, we only need to specify the `--out` argument.

### Miscellaneous

Of course, no Python module is complete without its imports. In this case, only one import is required:

```python
import wallaroo
```

## Running `alerts.py`

The complete example is available [here](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/python/alerts_stateless/). To run it, follow the [Reverse application instructions](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/python/alerts_stateless/README.md)

## Next Steps

To learn how to write a stateful application, continue to [Writing Your Own Stateful Application](writing-your-own-stateful-application.md).
