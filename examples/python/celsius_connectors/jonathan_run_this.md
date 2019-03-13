machida:

```bash
export PYTHONPATH="$PYTHONPATH:/home/nisan/wallaroo-tutorial/wallaroo/machida/lib/:/home/nisan/wallaroo-tutorial/wallaroo/testing/tools"

export PATH=$PATH:/home/nisan/wallaroo-tutorial/wallaroo/machida/build

machida --application-module celsius --metrics 127.0.0.1:5001 --control 127.0.0.1:76000 --data 127.0.0.1:6001 --name initializer --external 127.0.0.1:5050 --cluster-initializer --ponythreads=1 --ponynoblock
```


Data receiver:
```bash
```

Sender:
```
export PYTHONPATH="$PYTHONPATH:/home/nisan/wallaroo-tutorial/wallaroo/machida/lib/:/home/nisan/wallaroo-tutorial/wallaroo/testing/tools"

./at_least_once_feed
```
