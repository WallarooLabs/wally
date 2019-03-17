### Data receiver:

```bash
export PATH=$PATH:/home/nisan/wallaroo-tutorial/wallaroo/utils/data_receiver

data_receiver --ponythreads=1 --ponynoblock --listen 127.0.0.1:7200
```

### machida:

build with
```
make PONYCFLAGS="-Dcheckpoint_trace"  build-machida debug=true resilience=on
```

Initializer
```bash
export PYTHONPATH="$PYTHONPATH:/home/nisan/wallaroo-tutorial/wallaroo/machida/lib/:/home/nisan/wallaroo-tutorial/wallaroo/testing/tools"

export PATH=$PATH:/home/nisan/wallaroo-tutorial/wallaroo/machida/build

machida --application-module celsius --in 127.0.0.1:7100 --out 127.0.0.1:7200 --metrics 127.0.0.1:5000 --control 127.0.0.1:8000 --data 127.0.0.1:9000 --name initializer --external 127.0.0.1:6000 --cluster-initializer --ponythreads=1 --ponynoblock --run-with-resilience
```

Joiner

```bash
export PYTHONPATH="$PYTHONPATH:/home/nisan/wallaroo-tutorial/wallaroo/machida/lib/:/home/nisan/wallaroo-tutorial/wallaroo/testing/tools"

export PATH=$PATH:/home/nisan/wallaroo-tutorial/wallaroo/machida/build

machida --application-module celsius --in 127.0.0.1:7101 --out 127.0.0.1:7200 --metrics 127.0.0.1:5000 --my-control 127.0.0.1:8001 --my-data 127.0.0.1:9001 --name worker1 --external 127.0.0.1:6001 --join 127.0.0.1:8000 --ponythreads=1 --ponynoblock --run-with-resilience
```

Shrink
```
export PATH=$PATH:/home/nisan/wallaroo-tutorial/wallaroo/utils/cluster_shrinker
cluster_shrinker --external 127.0.0.1:6000 --count 1
```

### Sender:

For now, edit the `at_least_once_feed` file to change which files are sent and to which source address
We can modify that to use command args later

```
export PYTHONPATH="$PYTHONPATH:/home/nisan/wallaroo-tutorial/wallaroo/machida/lib/:/home/nisan/wallaroo-tutorial/wallaroo/testing/tools"

./at_least_once_feed
```

you might have to kill this sender with kill
```
ps aux | grep at_least_once
```

then

```
kill -9 <PID>
```
