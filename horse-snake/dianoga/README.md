# Dianoga

This is meant to be a proof-of-concept program that lets a user define
a Wallaroo application in Python.

## Build

Go to the `dianoga` directory.

```
cd horse-snake/dianoga
```

Create the `build` directory if it doesn't already exist.

```
mkdir build
```

Build the program.

```
clang -g -o build/python-wallaroo.o -c cpp/python-wallaroo.c
ar rvs build/libpython-wallaroo.a build/python-wallaroo.o
ponyc --debug --output=build --path=build --path=../../lib/ .
```

## Run Reverse Word (stateless computation)

Export the current directory as `PYTHONPATH`.

```
export PYTHONPATH=.
```

Set up a listener.

```
nc -l 127.0.0.1 7002
```

Run an application.

```
build/dianoga --wallaroo-module reverse_word -i 127.0.0.1:7010 -o 127.0.0.1:7002 -m 127.0.0.1:8000 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n worker-name --ponythreads=1
```

Send some messages

```
../../giles/sender/sender --buffy 127.0.0.1:7010 --file ./words.txt --batch-size 5 --interval 100_000_000 --messages 150 --repeat --ponythreads=1
```

The messages have a 32-bit big-endian integer that represents the
message length, followed by the message (in this case, a string that
you want to reverse). The output on the listener should be `olleh`.

## Run Alphabet (stateful computation)

Export the current directory as `PYTHONPATH`.

```
export PYTHONPATH=.
```

Set up a listener.

```
nc -l 127.0.0.1 7002 > alphabet.out
```

Run an application.

```
build/dianoga --wallaroo-module alphabet -i 127.0.0.1:7010 -o 127.0.0.1:7002 -m 127.0.0.1:8000 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n worker-name --ponythreads=1
```

Send some messages

```
../../giles/sender/sender --buffy 127.0.0.1:7010 --file votes.msg --batch-size 5 --interval 100_000_000 --messages 150 --binary --variable-size --repeat --ponythreads=1
```

The messages have a 32-bit big-endian integer that represents the
message length, followed by a byte that represents the character that
is being voted on, followed by a 32-bit big-endian integer that
represents the number of votes received for that letter. The output is
a byte representing the chrater that is being voted on, followed by
the total number of votes for that character. You can view the output
file with a tool like `hexdump`.

## Run Marketspread (stateful computation)

Export the current directory as `PYTHONPATH`.

```
export PYTHONPATH=.
```

Set up a listener.

```
nc -l 127.0.0.1 7002 > marketspread.out
```

Run an application.

```
build/dianoga --wallaroo-module market_spread \
-i 127.0.0.1:7010,127.0.0.1:7011 -o 127.0.0.1:7002 -m 127.0.0.1:8000 \
-c 127.0.0.1:6000 -d 127.0.0.1:6001 -n worker-name --ponythreads=1
```

Send some market data messages

```
../../giles/sender/sender --buffy 127.0.0.1:7011 --file ../../demos/marketspread/350k-nbbo-fixish.msg --batch-size 20 --interval 100_000_000 --messages 1000000 --binary --repeat --ponythreads=1 --msg-size 46 --no-write
```

and some orders messages

```
../../giles/sender/sender --buffy 127.0.0.1:7010 --file ../../demos/marketspread/350k-orders-fixish.msg --batch-size 20 --interval 100_000_000 --messages 1000000 --binary --repeat --ponythreads=1 --msg-size 57 --no-write
```
