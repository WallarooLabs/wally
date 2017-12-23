# Market Spread

## About The Application

This is a version of the Python Market Spread example application using struct serialization for better performance when testing multi-worker and resilience.

You can read more about Market Spread in [What is Wallaroo](/book/what-is-wallaroo.md)


## Running Market Spread

In order to run the application you will need Machida, Giles Sender, and the Cluster Shutdown tool. To build them, please see the [Linux](/book/getting-started/linux-setup.md) or [MacOS](/book/getting-started/macos-setup.md) setup instructions.

You will need five separate shells to run this application. Open each shell and go to the `testing/performance/apps/python/market_spread` directory.

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
../../../../../giles/sender/sender --host 127.0.0.1:7011 --file \
  ../../../../testing/data/market_spread/nbbo/350-symbols_initial-nbbo-fixish.msg \
  --batch-size 20 --interval 100_000_000 --messages 350 --binary \
  --ponythreads=1 --ponynoblock --msg-size 46 --no-write
```

### Shell 4

To send market messages, run this command:

```bash
../../../../../giles/sender/sender --host 127.0.0.1:7011 --file \
  ../../../../testing/data/market_spread/nbbo/350-symbols_nbbo-fixish.msg \
  --batch-size 20 --interval 100_000_000 --messages 1000000 --binary \
  --repeat --ponythreads=1 --ponynoblock --msg-size 46 --no-write
```

Once you've started sending Market messages, go to the next section to start sending order messages.

### Shell 5

To send order messages, run this command:

```bash
../../../../../giles/sender/sender --host 127.0.0.1:7010 --file \
  ../../../../testing/data/market_spread/orders/350-symbols_orders-fixish.msg \
  --batch-size 20 --interval 100_000_000 --messages 1000000 --binary \
  --repeat --ponythreads=1 --ponynoblock --msg-size 57 --no-write
```

## Shutdown

The sender commands will send data for a long time, so processing never really finishes. When you are ready to shut down the cluster you can run this command:

```bash
../../../../../utils/cluster_shutdown/cluster_shutdown 127.0.0.1:5050
```

You can shut down Giles Sender by pressing `Ctrl-c` from its shell.
