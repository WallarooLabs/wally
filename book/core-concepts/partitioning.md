# Partitioning

If all of the application state exists in one state object then only one state computation at a time can access that state object. In order to leverage concurrency, that state needs to be divided into multiple distinct state objects. Wallaroo can then automatically distribute these objects in a way that allows them to be accessed by state computations in parallel.

For example, in an application that keeps track of stock prices, the naïve application state might be a dictionary where the stock symbol is used to look up the price of the stock.

{% codetabs name="Python", type="py" -%}
# Message type
class Stock(object):
    def __init__(self, stock, price):
        self.stock = stock
        self.price = price

# State type
class Stocks(object):
    stocks = {}

    def set(self, symbol, price):
        self.stocks[symbol] = price
{%- endcodetabs %}

If a message came into the system with a new stock price, the state computation would take that message, get the symbol and the price, and use them to update the state.

{% codetabs name="Python", type="py" -%}
@wallaroo.state_computation("update stock", state=Stocks)
def update_stock(stock, state):
    state.set(stock.symbol, stock.price)
    return None
{%- endcodetabs %}

However, only one state computation may access the state at a time, so in this cases messages are handled one at a time.

If we could break the state into pieces and tell Wallaroo about those pieces, then we could process many messages concurrently. In the example, each stock could be broken out into its own piece of state. This is possible because in the model the price of each stock is independent of the price of any other stock, so modifying one has no effect on any of the others.

## State Partitioning

Wallaroo supports parallel execution by way of _state partitioning_. The state is broken up into distinct parts, and Wallaroo manages access to each part so that they can be accessed in parallel.
To do this, a _key extractor function_ is used to determine which _state partition_ a particular message should be sent to. Once the _partition_ is determined, the message and the associated _state partition_ are passed to a state computation to perform the update logic.

### Partitioned State

In order to take advantage of state partitioning, state objects need to be broken down. In the stock example there is already a class that represents an individual stock. However, Wallaroo state must be initialized either without an `__init__` method, or with an `__init__` method that only takes `self` as an argument. This means that we need a way to represent a zero state for a stock. Since we will be partitioning by symbols, and partition keys are implicit for a state computation, we can represent our state as a simple stock price representation:

{% codetabs name="Python", type="py" -%}
class StockPrice(object):
    price = 0.0
{%- endcodetabs %}

Since the state computation only has one stock in its state now, there is no need to do a dictionary look up. Instead, the state computation can update the particular Stock's state right away:

{% codetabs name="Python", type="py" -%}
@wallaroo.state_computation(name="update stock", state=StatePrice)
def update_stock(stock, state):
    state.price = stock.price
    return None
{%- endcodetabs %}

### Partition Key

State partitions will be generated from the keys that are derived from the key extractor function. 

### Key Extractor Function

The key extractor function takes in message data and returns a partition key. In the example, the message symbol would be extracted from the message data and returned as the key.

{% codetabs name="Python", type="py" -%}
@wallaroo.key_extractor
def extract_symbol(data):
    return data.symbol
}{%- endcodetabs %}
