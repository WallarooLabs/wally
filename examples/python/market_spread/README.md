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

As mentioned above, Market Spread has two input streams, each of which takes messages in a specific format. Both streams use the [source message framing protocol](https://docs.wallaroolabs.com/book/appendix/tcp-decoders-and-encoders.html#framed-message-protocols#source-message-framing-protocol).

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

The output messages use the [source message framing protocol](https://docs.wallaroolabs.com/book/appendix/tcp-decoders-and-encoders.html#framed-message-protocols#source-message-framing-protocol) and have the following parts:
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

In order to run the application you will need Machida, Giles Sender, and the Cluster Shutdown tool. We provide instructions for building these tools yourself and we provide prebuilt binaries within a Docker container. Please visit our [setup](/book/getting-started/choosing-an-installation-option.md) instructions to choose one of these options if you have not already done so.

You will need five separate shells to run this application. Open each shell and go to the `examples/python/market_spread` directory.

### Shell 1

Run `nc` to listen for TCP output on `127.0.0.1` port `7002`:

```bash
nc -l 127.0.0.1 7002 > marketspread.out
```

### Shell 2

Set `PATH` to refer to the directory that contains the `machida` executable. Set `PYTHONPATH` to refer to the current directory (where `market_spread.py` is) and the `machida` directory (where `wallaroo.py` is). Assuming you installed Wallaroo according to the tutorial instructions you would do:

**Note:** If running in Docker, the `PATH` and `PYTHONPATH` variables are pre-set for you to include the necessary directories to run this example.

```bash
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build:$HOME/wallaroo-tutorial/wallaroo/giles/sender:$HOME/wallaroo-tutorial/wallaroo/utils/cluster_shutdown"
export PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo-tutorial/wallaroo/machida"
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

Set `PATH` to refer to the directory that contains the `sender`  executable. Assuming you installed Wallaroo according to the tutorial instructions you would do:

**Note:** If running in Docker, the `PATH` variable is pre-set for you to include the necessary directories to run this example.

```bash
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build:$HOME/wallaroo-tutorial/wallaroo/giles/sender:$HOME/wallaroo-tutorial/wallaroo/utils/cluster_shutdown"
```

First prime the market data state with these initial messages, sent in via Giles Sender:

```
sender --host 127.0.0.1:7011 --file \
  ../../../testing/data/market_spread/nbbo/350-symbols_initial-nbbo-fixish.msg \
  --batch-size 20 --interval 100_000_000 --messages 350 --binary \
  --ponythreads=1 --ponynoblock --msg-size 46 --no-write
```

This will run for a few seconds and then terminate.

### Shell 4

Set `PATH` to refer to the directory that contains the `sender`  executable. Assuming you installed Wallaroo according to the tutorial instructions you would do:

**Note:** If running in Docker, the `PATH` variable is pre-set for you to include the necessary directories to run this example.

```bash
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build:$HOME/wallaroo-tutorial/wallaroo/giles/sender:$HOME/wallaroo-tutorial/wallaroo/utils/cluster_shutdown"
```

To send market messages, run this command:

```bash
sender --host 127.0.0.1:7011 --file \
  ../../../testing/data/market_spread/nbbo/350-symbols_nbbo-fixish.msg \
  --batch-size 20 --interval 100_000_000 --messages 1000000 --binary \
  --repeat --ponythreads=1 --ponynoblock --msg-size 46 --no-write
```

This will run until all 1,000,000 messages are processed; it can be stopped by `ctrl-c`.

Once you've started sending Market messages, go to the next section to start sending order messages.

### Shell 5

Set `PATH` to refer to the directory that contains the `sender`  executable. Assuming you installed Wallaroo according to the tutorial instructions you would do:

**Note:** If running in Docker, the `PATH` variable is pre-set for you to include the necessary directories to run this example.

```bash
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build:$HOME/wallaroo-tutorial/wallaroo/giles/sender:$HOME/wallaroo-tutorial/wallaroo/utils/cluster_shutdown"
```

To send order messages, run this command:

```bash
sender --host 127.0.0.1:7010 --file \
  ../../../testing/data/market_spread/orders/350-symbols_orders-fixish.msg \
  --batch-size 20 --interval 100_000_000 --messages 1000000 --binary \
  --repeat --ponythreads=1 --ponynoblock --msg-size 57 --no-write
```

This will run until all 1,000,000 messages are processed; it can be stopped by `ctrl-c`.

## Shutdown

Set `PATH` to refer to the directory that contains the `cluster_shutdown` executable. Assuming you installed Wallaroo  according to the tutorial instructions you would do:

**Note:** If running in Docker, the `PATH` variable is pre-set for you to include the necessary directories to run this example.

```bash
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build:$HOME/wallaroo-tutorial/wallaroo/giles/sender:$HOME/wallaroo-tutorial/wallaroo/utils/cluster_shutdown"
```

The sender commands will send data for a long time, so processing never really finishes. When you are ready to shut down the cluster you can run this command:

```bash
cluster_shutdown 127.0.0.1:5050
```

You can shut down the Giles Senders by pressing `Ctrl-c` from their shells.
