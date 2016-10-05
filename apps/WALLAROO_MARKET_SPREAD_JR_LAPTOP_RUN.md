# Running Wallaroo Market Spread Jr locally on OSX:

## Download the UI binaries:

`https://s3.amazonaws.com/sendence-dev/wallaroo/ui-bins/market_spread_reports_ui.tar.gz`

`https://s3.amazonaws.com/sendence-dev/wallaroo/ui-bins/metrics_reporter_ui.tar.gz`

After downloading and untarring, there will be a `metrics_reporter_ui` and `market_spread_reports_ui` binary in the respective `bin/` folders where extracted.

##Building Market Spread Jr:

to build market-spread-jr run `make build-apps-market-spread-jr` in the `Buffy` directory

##Building Giles Sender:

to build giles sender run `make build-giles-sender` in the `Buffy` directory


##Starting the UIs

### Starting Metrics Reporter UI

run `bin/metrics_reporter_ui start` from the directory you extracted the contents of the tar above

visit `http://localhost:4000` to verify it is up and running

### Starting Market Spread Reports UI

run `bin/market_spread_reports_ui start` from the directory you extracted the contents of the tar above

visit `http://localhost:4001` to verify it is up and running

##Starting Market Spread Jr

from the `apps/market-spread-jr` run the following:

```
./market-spread-jr -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -f ../../demos/marketspread/initial-nbbo-fixish.msg -e 150000000 -n node-name
```

##Starting the NBBO Stream

from the main Buffy directory run:

```
./giles/sender/sender -b 127.0.0.1:7000 -m 100000000 -s 300 -i 2_500_000 -f demos/marketspread/350k-nbbo-fixish.msg -r --ponythreads=1 -y -g 46 -w
```

##Starting the Orders Stream

from the main Buffy directory run:

```
giles/sender/sender -b 127.0.0.1:7001 -m 50000000 -s 300 -i 5_000_000 -f demos/marketspread/350k-orders-fixish.msg -r --ponythreads=1 -y -g 57 -w
```

##Stopping the UIs

### Stopping Metrics Reporter UI

run `bin/metrics_reporter_ui stop` from the directory you extracted the contents of the tar above

you'll receive an `ok` response letting you know it was successfully killed

### Stopping Market Spread Reports UI

run `bin/market_spread_reports_ui stop` from the directory you extracted the contents of the tar above

you'll receive an `ok` response letting you know it was successfully killed
