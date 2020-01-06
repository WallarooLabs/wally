---
title: "Writing Your Own Application"
menu:
  toc:
    parent: "ponytutorial"
    weight: 20
toc: true
---
In this section, we will go over the components that are required in order to write a Wallaroo Pony application. We will start with the [stateless `alerts.pony` application](https://github.com/WallarooLabs/wallaroo/tree/{{% wallaroo-version %}}/examples/pony/alerts_stateless/) from the [examples](https://github.com/WallarooLabs/wallaroo/tree/{{% wallaroo-version %}}/examples/) section, then move on to an application that maintains and modifies state and uses partitioning to divide its work.

## A Stateless Application - Alerts

The `alerts.pony` application is going to receive transactions as its input stream, check for certain conditions that should trigger alerts, and then send out any triggered alerts to its sink. In order to do this, our application needs to provide the following functions:

* Computation - this is where the input transaction will be checked for a potential alert condition
* Output encoding - how to construct and format the byte stream that will be sent out by the sink

### Computation

Let's start with the computation, because that's the purpose of the application:

```
primitive CheckTransaction is StatelessComputation[Transaction, (Alert | None)]
  fun apply(transaction: Transaction): (Alert | None) =>
    if transaction.amount > 1000 then
      DepositAlert(transaction.amount)
    elseif transaction.amount < -1000 then
      WithdrawalAlert(transaction.amount)
    else
      None
    end

  fun name(): String => "Check Transaction"
```

A Computation has no state, so it only needs to define its name, and how to convert input data into output data. In this case, we check whether certain conditions are met in order to decide whether to return a result. Returning nothing means we drop this message on the floor (we're done with it if no alert is needed).

### Sink Encoder

Next, we are going to define how the output gets constructed for the sink. It is important to remember that Wallaroo sends its output over the network, so data going through the sink needs to be of type `Array[ByteSeq]`. In Pony, this is the same as `String`

```
primitive AlertsEncoder
  fun apply(alert: Alert, wb: Writer): Array[ByteSeq] val =>
    wb.write(alert.string())
    wb.done()
```

### Source Decoder

For simplicity's sake, we are using an internal test generator source to simulate a stream of inputs into the application. In a real application, you will probably be receiving inputs in a binary format. If so, you need to define a decoder for converting those bytes to your input types. For more on this, please refer to the [Creating A Decoder](/pony-tutorial/tcp-decoders-and-encoders/#creating-a-decoder) section.

### Application Setup

So now that we have our computation and output encoding defined, how do we build it all into an application?
For this,we need the actual topology `Wallaroo.build_application` is going to return for Wallaroo to create the application.

An application is constructed of one or more pipelines which can be merged at various points until they converge on one or more sinks. Our alerts application has only one source stream, so we only need to create one (called `transactions`):

```
let transactions = Wallaroo.source[Transaction]("Alerts (stateless)",
    GenSourceConfig[Transaction](TransactionsGeneratorBuilder))
```

We are using a `GenSource` in order to simulate inputs to the application.

Next, we add the computation stage:

```
.to[Alert](CheckTransaction)
```

Wallaroo provides a scale-independent API. That means that we try to parallelize work when it is beneficial. Our default is to parallelize stateless computations, which means that there is no guarantee the outputs downstream will arrive in the same order as the inputs. If for some reason you need to guarantee that your inputs maintain their order, then you should precede the call to `to[Alert]` with a `key_by`:

```
.key_by(ExtractUser)
.to[Alert](CheckTransaction)

primitive ExtractUser
  fun apply(t: Userable): String =>
    t.user()
```

We explain `key_by` in more detail and with examples in [Writing Your Own Stateful Application](/pony-tutorial/writing-your-own-stateful-application/).

Finally, after adding our computation stage, we add the sink, using a `TCPSinkConfig`:

```
.to_sink(TCPSinkConfig[Alert].from_options(
  AlertsEncoder, TCPSinkConfigCLIParser(env.args)?(0)?))
```

### The `Main` Entry Point

Like other compiled languages such as C, C++, or Java, a Pony too has a `Main` that is required for an application to start. In Pony `Main` is an actor and the `create` function is where we define what we want our application to do. It is in this function where the stages from above are going to be defined.

```
actor Main
  new create(env: Env) =>
    Log.set_defaults()
    try
      let pipeline = recover val
        let transactions = Wallaroo.source[Transaction]("Alerts (stateless)",
          GenSourceConfig[Transaction](TransactionsGeneratorBuilder))

        transactions
          .to[Alert](CheckTransaction)
          .to_sink(TCPSinkConfig[Alert].from_options(
            AlertsEncoder, TCPSinkConfigCLIParser(env.args)?(0)?))
      end
      Wallaroo.build_application(env, "Alerts", pipeline)
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end
```

Wallaroo provides the convenience primitives `TCPSourceConfigCLIParser` and `TCPSinkConfigCLIParser` to parse host and port information that is passed on the command line, or the user can supply their own code for getting these values. When using the convenience primitives, host/port pairs are represented on the command line as colon-separated values and multiple host/port values are represented by a comma-separated list of host/port values. The primitives assume that `--in` is used for input addresses, and `--out` is used for output addresses. For example, this set of command line arguments would specify two input (name, host, port) values and one output:

```
--in Alerts@localhost:7001,Alerts@localhost:7002 --out localhost:7010
```

Since we are using an internal `GenSource` for our example, we only need to specify the `--out` argument.

## Running `alerts.pony`

The complete example is available [here](https://github.com/WallarooLabs/wallaroo/tree/{{% wallaroo-version %}}/examples/pony/alerts_stateless/). To run it, follow the [instructions](https://github.com/WallarooLabs/wallaroo/tree/{{% wallaroo-version %}}/examples/pony/alerts_stateless/README.md)

## Next Steps

To learn how to write a stateful application, continue to [Writing Your Own Stateful Application](/pony-tutorial/writing-your-own-stateful-application/).
