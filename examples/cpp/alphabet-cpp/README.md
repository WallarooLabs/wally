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

Start the Metrics UI if it isn't already running:
    ```bash
    docker start mui
    ```

In a separate shell each:

1. Start a listener with Giles Receiver
    ```bash
    ../../../../giles/receiver/receiver --ponythreads=1 --ponynoblock \
      --ponypinasio -l 127.0.0.1:7002 --no-write
    ```
2. Start the application
    ```bash
    ./build/alphabet-app --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
      --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
      --worker-name worker-name --cluster-initializer --ponythreads=1
    ```
3. Start sending data
    ```bash
     ../../../../giles/sender/sender --host 127.0.0.1:7010 --file votes.msg \
       --batch-size 50 --interval 10_000_000 --binary --msg-size 9 --repeat \
       --ponythreads=1 --messages 1000000 --no-write
    ```
