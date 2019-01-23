---
title: "Writing Your Own Stateful Application"
menu:
  docs:
    toc: "pytutorial"
    weight: 30
toc: true
---
In this section, we will go over how to write a stateful application with the Wallaroo Python API. If you haven't reviewed the simple stateless Alerts application example yet, you can find it [here](/python-tutorial/writing-your-own-application/).

## A Stateful Application - Alphabet

Our stateful application is going to add state to the Alerts example. Again, it receives as its inputs messages representing transactions. But now instead of statelessly checking individual transactions to see if they pass certain thresholds, it will add each transaction amount to a running total. It will then check that total to see if an alert should be emitted.

As with the stateless Alerts example, we will list the components required:

* Output encoding
* Computation for checking transactions
* State object

### State Computation

The state computation here is fairly straightforward: given a data object and a state object, update the state with the new data, and, based on a simple condition, determine whether we return some data representing an alert message.

Our input type represents a transaction:
```python
class Transaction(object):
    def __init__(self, user, amount):
        self.user = user
        self.amount = amount
```

We use these inputs to update state, and check whether the running total crosses certain thresholds, at which point we generate an alert:

```python
@wallaroo.state_computation(name="check transaction total", state=TransactionTotal)
def check_transaction_total(transaction, state):
    state.total = state.total + transaction.amount
    if state.total > 2000:
        return DepositAlert(transaction.user, state.total)
    elif state.total < -2000:
        return WithdrawalAlert(transaction.user, state.total)
```

### State

The state for this application keeps track of a running total of transactions:

```python
class TransactionTotal(object):
    def __init__(self):
        self.total = 0
```

### Encoder
The encoder is going to receive either a `DepositAlert` or `WithdrawalAlert` instance and encode it into a string. Since we only generate alerts when certain conditions are met, not every input into the application results in an output sent to the sink.

As with our previous stateless example, the sink requires a `bytes` object. In Python 2 this can be the string itself, but in Python 3 we need to encode it from unicode to `bytes`. Luckily, we can use `encode()` to get a `bytes` from a string in both versions:

```python
@wallaroo.encoder
def encode_alert(alert):
    return str(alert).encode()
```

### Partitioning
In our stateless example, we looked at each transaction input in isolation and generated an alert based on its properties. This meant that Wallaroo could process all of these transactions in parallel without concern for how they were related to each other. But in our stateful example, we are accumulating totals. What do these totals refer to? For this application, they are the running totals per user. So each transaction object is associated with a particular user.

This means that a natural way to partition the work is by user. We accomplish this by defining a function for extracting keys from our input messages:

```python
@wallaroo.key_extractor
def extract_user(transaction):
    return transaction.user
```

### Application Setup

Finally, let's set up our application topology:

```python
def application_setup(args):
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    gen_source = wallaroo.GenSourceConfig(TransactionsGenerator())

    transactions = wallaroo.source("Alerts (stateful)", gen_source)
    pipeline = (transactions
        .key_by(extract_user)
        .to(check_transaction_total)
        .to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encode_alert)))

    return wallaroo.build_application("Alerts (stateful)", pipeline)
```

The important difference between this setup and the stateless version from our last example (besides using a state computation rather than a stateless one) is the presence of: 

```python
.key_by(extract_user)
```

This ensures that all transactions for a given user are sent to the same state
partition. This means that when defining our state type, we can take for granted that the key is an implicit context. We don't need to refer to the user
anywhere in the state definition if we don't want to (and in this case we don't need to).

### Miscellaneous

This module needs its imports:

```python
import wallaroo
```

## Next Steps

The complete stateful alerts example is available [here](https://github.com/WallarooLabs/wallaroo/tree/{{% wallaroo-version %}}/examples/python/alerts_stateful/). To run it, follow the [Alerts application instructions](https://github.com/WallarooLabs/wallaroo/tree/{{% wallaroo-version %}}/examples/python/alerts_stateful/README.md)

To learn how to make your application resilient and able to work across multiple workers, skip ahead to [Inter-worker Serialization and Resilience](/python-tutorial/interworker-serialization-and-resilience/). Otherwise, continue on to the next section of the tutorial, [Word Count](/python-tutorial/word-count/).
