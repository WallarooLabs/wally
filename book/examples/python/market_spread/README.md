# Market Spread

Set up a listener.

```bash
nc -l 127.0.0.1 7002 > marketspread.out
```

In another shell, export the current directory and `wallaroo.py` directories to `PYTHONPATH`:

```bash
export PYTHONPATH="$PYTHONPATH:.:../../../../machida"
```

Export the machida binary directory t `PATH`:

```bash
export PATH="$PATH:../../../../machida/build"
```

Run `machida` with `--application-module market_spread`:

```bash
machida --application-module market_spread \
-i 127.0.0.1:7010,127.0.0.1:7011 -o 127.0.0.1:7002 -m 127.0.0.1:8000 \
-c 127.0.0.1:6000 -d 127.0.0.1:6001 -n worker-name --ponythreads=1
```

Send some market data messages

```bash
../../../../giles/sender/sender --buffy 127.0.0.1:7011 --file \
../../../../demos/marketspread/350k-nbbo-fixish.msg --batch-size 20 \
--interval 100_000_000 --messages 1000000 --binary --repeat --ponythreads=1 -\
-msg-size 46 --no-write
```

and some orders messages

```bash
../../../../giles/sender/sender --buffy 127.0.0.1:7010 --file \
../../../../demos/marketspread/350k-orders-fixish.msg --batch-size 20 \
--interval 100_000_000 --messages 1000000 --binary --repeat --ponythreads=1 \
--msg-size 57 --no-write
```
