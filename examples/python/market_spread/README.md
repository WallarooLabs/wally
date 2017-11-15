# Market Spread

## About The Application

Market Spread is an application designed to run alongside a trading system. Its goal is to monitor market data for irregularities around different symbols and potentially withdraw some trades that have been sent to market should certain anomalies occur.

When we break the application down into its key components we get:

- A stream of market data which we refer to as the “Market Stream”
- A stream of trades which we refer to as the “Order Stream”
- State in the form of latest market conditions for various stock symbols
- A calculation to possibly withdraw the trade based on state for that stock symbol

You can read more about Market Spread in [What is Wallaroo](/book/what-is-wallaroo.md)

### Input

As mentioned above, Market Spread has two input streams, each of which takes messages in a specific format. Both streams use the [source message framing protocol](/book/core-concepts/decoders-and-encoders.md#framed-message-protocols#source-message-framing-protocol).

#### NBBO Messages

NBBO messages have the following parts:
* *fix type* -- the type of the message, 1 byte
* *symbol* -- the stock symbol that the message is for, 4 byte string
* *transact time* -- the time of the transaction, 21 byte string
* *bid price* -- the bid price for this stock, 64-bit float
* *offer price* -- the offer price this stock, 64-bit float

#### Order Messages

Order messages have the following parts:
* *fix type* -- the type of the message, 1 byte
* *side* -- the side of the order (buy or sell), 1 byte
* *account* -- the account that placed this order, 32-bit integer
* *order id* -- the id of the order, 6 byte string
* *symbol* -- the stock symbol for the order, 4 byte string
* *order quantity* -- the quantity of shares to be purchased in this order, 64-bit float
* *price* -- the price of the shares in this order, 64-bit float
* *transact time* -- the time of the transaction, 21 byte string

### Output

The output messages use the [source message framing protocol](/book/core-concepts/decoders-and-encoders.md#framed-message-protocols#source-message-framing-protocol) and have the following parts:
* *side* -- the side of the order (buy or sell), 1 byte
* *account* -- the account that placed this order, 32-bit integer
* *order id* -- the id of the order, 6 byte string
* *symbol* -- the stock symbol for the order, 4 byte string
* *order quantity* -- the quantity of shares to be purchased in this order, 64-bit float
* *price* -- the price of the shares in this order, 64-bit float
* *bid* -- the bid for the order, 64-bit float
* *offer* -- the offer for the order, 64-bit float
* *transact time* -- the time of the transaction, 21 byte string

### Processing

The NBBO messages are handled by the `MarketDataDecoder`'s `decode(...)` method, which takes the input bytes and turns them into `MarketDataMessage` objects, which are then sent to the state partition that handles the state for the stock symbol given by the message, along with the `UpdateMarketData` object. The `UpdateMarketData`'s `compute(...)` method is called on the incoming message and the current state for the stock symbol and the state is updated with new price information.

The Order messages are handled by the `OrderDecoder`'s `decode(...)` method, which takes the input bytes and turns them into `Order` object, which are then sent to the state partition that handles the state for the stock symbol given in the message, along with the `CheckOrder` object. The `CheckOrder`'s `compute(...)` method is called on the incoming message and the current state for the stock symbol, and if the order is accepted based on the order price and the market price then an `OrderResult` message is sent out. The `Encoder`'s `encode(...)` method turns `OrderResult` messages into byte strings that are then sent out.

## Running Market Spread

In order to run the application you will need Machida, Giles Sender, and the Cluster Shutdown tool. To build them, please see the [Linux](/book/getting-started/linux-setup.md) or [Mac OS](/book/getting-started/macos-setup.md) setup instructions. Alternatively, they could be run in Docker, please see the [Docker](/book/getting-started/docker-setup.md) setup instructions and our [Run an Application in Docker](/book/getting-started/run-a-wallaroo-application-docker.md) guide if you haven't already done so.

Note: If running in Docker, the relative paths are not necessary for binaries as they are all bound to the PATH within the container. You will not need to set the `PATH` variable and `PYTHONPATH` already includes the current working directory.

You will need five separate shells to run this application. Open each shell and go to the `examples/python/market_spread` directory.

### Shell 1

Run `nc` to listen for TCP output on `127.0.0.1` port `7002`:

```bash
nc -l 127.0.0.1 7002 > marketspread.out
```

### Shell 2

Set `PYTHONPATH` to refer to the current directory (where `market_spread.py` is) and the `machida` directory (where `wallaroo.py` is). Set `PATH` to refer to the directory that contains the `machida` executable. Assuming you installed Machida according to the tutorial instructions you would do:

```bash
export PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo-tutorial/wallaroo/machida"
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build"
```

Run `machida` with `--application-module market_spread`:

```bash
machida --application-module market_spread \
  --in 127.0.0.1:7010,127.0.0.1:7011 --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --worker-name worker1 --external 127.0.0.1:5050 --cluster-initializer \
  --ponythreads=1 --ponynoblock
```

### Shell 3

First prime the market data state with these initial messages, sent in via Giles Sender:

```
../../../giles/sender/sender --host 127.0.0.1:7011 --file \
  ../../../testing/data/market_spread/nbbo/350-symbols_initial-nbbo-fixish.msg \
  --batch-size 20 --interval 100_000_000 --messages 350 --binary \
  --ponythreads=1 --ponynoblock --msg-size 46 --no-write
```

### Shell 4

To send market messages, run this command:

```bash
../../../giles/sender/sender --host 127.0.0.1:7011 --file \
  ../../../testing/data/market_spread/nbbo/350-symbols_nbbo-fixish.msg \
  --batch-size 20 --interval 100_000_000 --messages 1000000 --binary \
  --repeat --ponythreads=1 --ponynoblock --msg-size 46 --no-write
```

Once you've started sending Market messages, go to the next section to start sending order messages.

### Shell 5

To send order messages, run this command:

```bash
../../../giles/sender/sender --host 127.0.0.1:7010 --file \
  ../../../testing/data/market_spread/orders/350-symbols_orders-fixish.msg \
  --batch-size 20 --interval 100_000_000 --messages 1000000 --binary \
  --repeat --ponythreads=1 --ponynoblock --msg-size 57 --no-write
```

## Shutdown

The sender commands will send data for a long time, so processing never really finishes. When you are ready to shut down the cluster you can run this command:

```bash
../../../utils/cluster_shutdown/cluster_shutdown 127.0.0.1:5050
```

You can shut down Giles Sender by pressing `Ctrl-c` from its shell.
