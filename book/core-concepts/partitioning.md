# Partitioning

If all of the application state exists in one state object then only one computation at a time can access that state object. In order to leverage concurrency, that state needs to be divided into multiple distinct state objects. Wallaroo can then automatically distribute these objects in a way that allows them to be accessed by computations in parallel.

For example, in an application that keeps track of stock prices, the application state might be a dictionary where the stock symbol is used to look up the price of the stock.

```pony
class Stock
  var symbol: String
  var price: F32

class Stocks
  let _stocks: Map[String, Stock]
  fun set(symbol: String, price: F32) =>
    let stock = _stocks(symbol)
    stock.price = price
```

If a message came into the system with a new stock price, the computation would take that message, get the symbol and the price, and use them to update the state.

```pony
class UpdateStock
  fun compute(message_data: MessageData, state: Stocks) =>
    symbol = message_data.symbol
    price = message_data.price
    state.set(symbol, price)
    // ...
```

However, only one computation may access the state at a time, so in this cases messages are handled one at a time.

If we could break the state into pieces and tell Wallaroo about those pieces then we could process many messages concurrently. In the example, each stock could be broken out into it's own piece of state. This is possible because in the model the price of each stock is independent of the price of any other stock, so modifying one has no effect on any of the others.

## State Partitioning

Wallaroo supports parallel execution by way of _state partitioning_. The state is broken up into distinct parts, and Wallaroo manages access to each part so that they can be accessed in parallel.
To do this, a _partition function_ is used to determine which _state part_ a particular data should be applied to. Once the _part_ is determined, the data and the associated _state part_ are given to a Computation to perform the update logic.

### Paritioned State

In order to take advantage of state partitioning, state objects need to be broken down. In the stock example there is already a class that represents an individual stock, so it can be used as the partitioned state.

```pony
class Stock
  var symbol: String
  var price: F32
```

Since the computation only has one stock in its state now, there is no need to do a dictionary look up. Instead, the computation can update the particular Stock's state right away.

```pony
class UpdateStock
  fun compute(message_data: MessageData, state: Stock) =>
    state.symbol = message_data.symbol
    state.price = message_data.price
    // ...
```

### Parition Key

Currently, the partition keys for a particular partition need to be defined along with the application. The specific details of keys vary between the different language APIs, but they are typically an object of some type that can support comparison and hashing. In the stock example, the partition key would be the symbol name (a string). All of the expected stock symbols are passed to the application setup code.


### Partition Function

The partition function takes in message data and returns a partition key. In the example, the message symbol would be extracted from the message data and returned as the key.

```pony
primitive StockPartitionFunction
  fun apply(stock: Stock val): String =>
    stock.symbol
```
