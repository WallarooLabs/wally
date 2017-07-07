# Market Spread

Market Spread is an application designed to run alongside a trading system. Its goal is to monitor market data for irregularities around different symbols and potentially withdraw some trades that have been sent to market should certain anomalies occur.

When we break the application down into its key components we get:

- A stream of market data, aka “NBBO Stream”
- A stream of trades, aka “Order Stream”
- State in the form of latest market conditions for various symbols
- A calculation to possibly withdraw the trade based on state for that symbol

You can read more about Market Spread in [What is Wallaroo](/book/what-is-wallaroo.md)
You will need a working [Wallaroo Python API](/book/python/intro.md).

## Running Market Spread

In a shell, start up the Metrics UI if you don't already have it running:

```bash
docker start mui
```

Set up a listener.

```bash
nc -l 127.0.0.1 7002 > marketspread.out
```

In another shell, set up your environment variables if you haven't already done so. Assuming you installed Machida according to the tutorial instructions you would do:

```bash
export PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo-tutorial/wallaroo/machida"
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build"
```

Run `machida` with `--application-module market_spread`:

```bash
machida --application-module market_spread \
  -i 127.0.0.1:7010,127.0.0.1:7011 -o 127.0.0.1:7002 -m 127.0.0.1:5001 \
  -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n worker-name --ponythreads=1
```

Send some market data messages

```bash
../../../../giles/sender/sender --host 127.0.0.1:7011 --file \
  ../../../../testing/data/market_spread/nbbo/350-symbols_nbbo-fixish.msg --batch-size 20 \
  --interval 100_000_000 --messages 1000000 --binary --repeat --ponythreads=1 \
  --msg-size 46 --no-write
```

and some orders messages

```bash
../../../../giles/sender/sender --host 127.0.0.1:7010 --file \
  ../../../../testing/data/market_spread/orders/350-symbols_orders-fixish.msg --batch-size 20 \
  --interval 100_000_000 --messages 1000000 --binary --repeat --ponythreads=1 \
  --msg-size 57 --no-write
```
