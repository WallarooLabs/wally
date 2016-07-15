
DOUBLE DIVIDE

Buffy:
```
./double-divide -l -w 0 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -r 127.0.0.1:7000 -k 127.0.0.1:8000 -n leader -p 127.0.0.1:11000 -m 127.0.0.1:9000 --ponythreads 3
```

Metrics Receiver:
```
./double-divide --run-sink -r -l 127.0.0.1:9000 -m 127.0.0.1:5001 -e 1 -a double-divide --ponythreads 1
```

Giles sender:
```
./sender -b 127.0.0.1:7000 -m 1000000 --ponythreads 1 -s 500
```

Giles receiver:
```
./receiver -l 127.0.0.1:8000 --ponythreads 1
```

Monitoring Hub:
```
iex --sname monitoring_hub -S mix phoenix.server
```


MARKET SPREAD

Buffy:
```
./market-spread -l -w 0 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -r 127.0.0.1:7000,127.0.0.1:7001 -k 127.0.0.1:8000,127.0.0.1:8001 -n leader -p 127.0.0.1:11000 -m 127.0.0.1:9000 --ponythreads 3
```

Giles sender:
```
./sender -b 127.0.0.1:7000 -m 1000000 -f ../../demos/marketspread/trades.msg -r --ponythreads 1 -s 500

./sender -b 127.0.0.1:7001 -m 1000000 -f ../../demos/marketspread/nbbo.msg -r --ponythreads 1 -s 500
```

Giles receiver:
```
./receiver -l 127.0.0.1:8000 --ponythreads 1
```

Metrics Receiver:
```
./market-spread --run-sink -r -l 127.0.0.1:9000 -m 127.0.0.1:5001 -e 1 -a market-spread --ponythreads 1
```

UI Report Sink node:
```
./market-spread --run-sink -l 127.0.0.1:8001 -t 127.0.0.1:5555 -p 127.0.0.1:11000 -n reports --ponythreads 1
```

Monitoring Hub:
```
iex --sname monitoring_hub -S mix phoenix.server
```
