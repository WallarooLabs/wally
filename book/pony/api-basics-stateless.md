# API Basics: Stateless App

## Defining an Application

We'll begin digging into the Wallaroo API by creating a linear pipeline of
stateless computations. All the code in this section can be found in
[`examples/pony/alerts_stateless/alerts.pony`](https://github.com/WallarooLabs/wallaroo-examples/tree/{{ book.wallaroo_version }}/examples/pony/alerts_stateless/alerts.pony).

We're going to start by creating an application that checks transactions to see if their amount is above or below a certain threshold (at which point we want to emit an alert). This might look something like the following:

```pony
primitive CheckTransaction is StatelessComputation[Transaction, (Alert | None)]
  fun apply(transaction: Transaction): (Alert | None) =>
    if transaction.amount > 1000 then
      DepositAlert(transaction.amount)
    elseif transaction.amount < -1000 then
      WithdrawalAlert(transaction.amount)
    else
      None
    end

  fun name(): String => "CheckTransaction"
```

A few points of interest. First, we name our computation `CheckTransaction` and define it as a `primitive`. You can think of a `primitive` as a stateless class. Second, we specify that `CheckTransaction` is a `StatelessComputation` transforming values of type
`Transaction` to values of type `Alert` (or `None` if there is no call for an alert). Third, we define an `apply` method that constitutes the computation logic itself. Finally, all `StatelessComputation` objects must implement a `name` method for performance monitoring purposes, so we include one here.

Our application consists of a simple pipeline which takes a `Transaction`, passes it to a `CheckTransaction`, which optionally passes an `Alert` to a sink for sending to external systems. Here is all the code for defining the application itself (we'll break it down step by step):

```pony
let pipeline = recover val
  let inputs = Wallaroo.source[Transaction]("Alerts (stateless)",
    GenSourceConfig[Transaction](TransactionsGenerator))
  inputs
    .to[Alert](CheckTransaction)
    .to_sink(TCPSinkConfig[Alert].from_options(
      AlertsEncoder, TCPSinkConfigCLIParser(env.args)?(0)?))
end
Wallaroo.build_application(env, "Alerts", pipeline)
```

We begin our application definition by defining a source stream called `transactions`:   

```
let transactions = Wallaroo.source[Transaction]("Alerts (stateless)",
    GenSourceConfig[Transaction](TransactionsGenerator))
```
We then define the computation these transactions are sent to:

```pony
  let pipeline = transactions
    .to[Alert](CheckTransaction)
```

This says that our transactions stream is sent to a `CheckTransaction` computation. The type argument tells us the _output_ type for the computation, in this case `Alert`. The system infers the input type for each computation. 

Finally we define our sink for the pipeline:

```pony
    .to_sink(TCPSinkConfig[Alert].from_options(
      AlertsEncoder, TCPSinkConfigCLIParser(env.args)?(0)?))
```

The `AlertsEncoder` transforms the `Alert` values to sequences of bytes for transmission via TCP. 

## Hooking into Wallaroo

In order to actually use our app, we need to pass the pipeline object we
just defined to Wallaroo. We'll create a file called `alerts.pony` and
define a `Main` actor (which is the Pony equivalent of `main()` in C). Here's
our pipeline definition in context:

```pony
actor Main
  new create(env: Env) =>
    try
      let pipeline = recover val
        let transactions = Wallaroo.source[Transaction]("Alerts (stateless)",
          GenSourceConfig[Transaction](TransactionsGenerator))

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

This application uses a `GenSource` in order to simulate inputs. You could also use a `TCPSource` to receive inputs over TCP or a `ConnectorSource` for integrating with external systems such as Kafka.

You can treat most of the new code here as boilerplate for now, except for this line:

```pony
      Wallaroo.build_application(env, "Alerts", pipeline)
```

The `Wallaroo.build_application` method is the entry point into Wallaroo itself. We pass the Pony environment, our pipeline, and a string to use for tagging files and metrics related to this app.

## Decoding and Encoding

If you are using TCP to send data in and out of the system, then you need a way
to convert streams of bytes into semantically useful types and convert your
output types to streams of bytes. This is where the decoders and encoders
mentioned earlier come into play. For more information, see
[Decoders and Encoders](decoders-and-encoders.md).
