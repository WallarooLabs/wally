# Alphabet

This example application lets people vote on their favorite letter of the alphabet (a-z). It receives messages that consist of a single byte representing a character and four bytes that represent the number of new votes that should be added for this character. Each time it receives one of these messages, it outputs a message that consists of a single byte that represents the character followed by four bytes that represent the total number of votes that letter has received. Both the incoming and outgoing messages are framed by a four byte lengths that represent the number of bytes in the message (not including the bytes in the framing). The framing length and vote counts are a 32-bit big-endian integers.

## Prerequisites

- [CPP setup instructions](/book/cpp/building.md)

## Building

```bash
mkdir build
```

**On MacOS**:

```bash
clang++ --debug -c -o build/alphabet.o cpp/alphabet.cpp -Wall -std=c++11 -Iinclude
ar rs build/libalphabet.a build/alphabet.o
ponyc --debug --export --output=build \
  --path=../../../../lib:../../../../cpp_api/cpp/cppapi/build/build/lib:./build:../../../../cpp_api \
    alphabet-app
```

**On Linux**:

```bash
g++ --debug -c -o build/alphabet.o cpp/alphabet.cpp -Wall -std=c++11 -Iinclude
ar rs build/libalphabet.a build/alphabet.o
ponyc --linker c++ --debug --export --output=build \
  --path=../../../../lib:../../../../cpp_api/cpp/cppapi/build/build/lib:./build:../../../../cpp_api \
    alphabet-app
```

## Running

You will need five separate shells to run this application. Open each shell and go to the `examples/cpp/alphabet-cpp` directory.

### Shell 1: Metrics UI

Start the Metrics UI if it isn't already running:

```bash
docker start mui
```

You can verify it started up correctly by visiting [http://localhost:4000](http://localhost:4000).

If you need to restart the UI, run:

```bash
docker restart mui
```

When it's time to stop the UI, run:

```bash
docker stop mui
```

If you need to start the UI after stopping it, run:

```bash
docker start mui
```

### Shell 2: Data Receiver

Start a listener with Giles Receiver

```bash
../../../../giles/receiver/receiver --ponythreads=1 --ponynoblock \
  --ponypinasio -l 127.0.0.1:7002 --no-write
```

### Shell 3: Alphabet-app

Start the application

```bash
./build/alphabet-app --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --worker-name worker-name --cluster-initializer --ponythreads=1 \
  --ponynoblock
```

### Shell 4: Sender

Start sending data

```bash
../../../../giles/sender/sender --host 127.0.0.1:7010 --file votes.msg \
  --batch-size 50 --interval 10_000_000 --binary --msg-size 9 --repeat \
  --ponythreads=1 --ponynoblock --messages 1000000 --no-write
```

If the sender is working correctly, you should see `Connected` printed to the screen. If you see that, you can be assured that we are now sending data into our example application.

## Shutdown

### Shell 5: Shutdown

You can shut down the cluster with this command at any time:

```bash
cd ~/wallaroo-tutorial/wallaroo/utils/cluster_shutdown
./cluster_shutdown 127.0.0.1:5050
```

You can shut down Giles Sender and Giles Receiver by pressing Ctrl-c from their respective shells.

You can shut down the Metrics UI with the following command:

```bash
docker stop mui
```
