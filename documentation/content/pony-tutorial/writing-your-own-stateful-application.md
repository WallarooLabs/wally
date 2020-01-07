---
title: "Writing Your Own Stateful Application"
menu:
  toc:
    parent: "ponytutorial"
    weight: 30
toc: true
---
In this section, we will go over how to write a stateful application with the Wallaroo Pony API. If you haven't reviewed the simple stateless Alerts application example yet, you can find it [here](/pony-tutorial/writing-your-own-application/).

## A Stateful Application - Alerts

Our stateful application is going to add state to the Alerts example. Again, it receives as its inputs messages representing transactions. But now instead of statelessly checking individual transactions to see if they pass certain thresholds, it will add each transaction amount to a running total. It will then check that total to see if an alert should be emitted.

As with the stateless Alerts example, we will list the components required:

* Output encoding
* Computation for checking transactions
* State object

### State Computation

The state computation here is fairly straightforward: given a data object and a state object, update the state with the new data, and, based on a simple condition, determine whether we return some data representing an alert message.

Our input type represents a transaction:
```
class val Transaction
  let _user: String
  let amount: USize
  new val create(u: String, a: USize) =>
    _user = u
    amount = a
  fun user(): String => _user
  fun string(): String =>
    "Transaction(" + _user + ":" + amount.string() + ")\n"
```

We use these inputs to update state, and check whether the running total crosses certain thresholds, at which point we generate an alert:

```
primitive CheckTransaction is StateComputation[Transaction, (Alert | None),
  TransactionTotal]

  fun apply(transaction: Transaction, t_total: TransactionTotal):
    (Alert | None)
  =>
    t_total.total = t_total.total + transaction.amount
    if t_total.total > 2000 then
      DepositAlert(transaction.user, t_total.total)
    elseif t_total.total < -2000 then
      WithdrawalAlert(transaction.user, t_total.total)
    else
      None
    end
```

### State

The state for this application keeps track of a running total of transactions:

```
class TransactionTotal is State
  var total: F64 = 0.0
```

### Encoder
The encoder is going to receive either a `DepositAlert` or `WithdrawalAlert` instance and encode it into a string. Since we only generate alerts when certain conditions are met, not every input into the application results in an output sent to the sink.

As with our previous stateless example, the sink requires a `Array[ByteSeq]` object and we'll use the `Writer` package to write our `String` out as that:

```
primitive AlertsEncoder
  fun apply(alert: Alert, wb: Writer): Array[ByteSeq] val =>
    wb.write(alert.string())
    wb.done()
```

### Partitioning
In our stateless example, we looked at each transaction input in isolation and generated an alert based on its properties. This meant that Wallaroo could process all of these transactions in parallel without concern for how they were related to each other. But in our stateful example, we are accumulating totals. What do these totals refer to? For this application, they are the running totals per user. So each transaction object is associated with a particular user.

This means that a natural way to partition the work is by user. We accomplish this by defining a function for extracting keys from our input messages:

```
primitive ExtractUser
  fun apply(t: Userable): String =>
    t.user()
```

### Application Setup

Finally, let's set up our application topology:

```
let pipeline = recover val
  let transactions = Wallaroo.source[Transaction]("Alerts (windowed)",
    GenSourceConfig[Transaction](TransactionsGeneratorBuilder))

  transactions
    .key_by(ExtractUser)
    .to[Alert](Wallaroo.range_windows(Seconds(5))
                .over[Transaction, Alert, TransactionTotal](
                  TotalAggregation))
    .to_sink(TCPSinkConfig[Alert].from_options(
      AlertsEncoder, TCPSinkConfigCLIParser(env.args)?(0)?))
end
Wallaroo.build_application(env, "Alerts", pipeline)
```

The important difference between this setup and the stateless version from our last example (besides using a state computation rather than a stateless one) is the presence of:

```
.key_by(ExtractUser)
```

This ensures that all transactions for a given user are sent to the same state
partition. This means that when defining our state type, we can take for granted that the key is an implicit context. We don't need to refer to the user
anywhere in the state definition if we don't want to (and in this case we don't need to).

## Next Steps

The complete stateful alerts example is available [here](https://github.com/WallarooLabs/wallaroo/tree/{{% wallaroo-version %}}/examples/pony/alerts_stateful/). To run it, follow the [Alerts application instructions](https://github.com/WallarooLabs/wallaroo/tree/{{% wallaroo-version %}}/examples/pony/alerts_stateful/README.md)

To learn how to write one of the canonical streaming data applications, continue on to the next section of the tutorial, [Word Count](/python-tutorial/word-count/).
