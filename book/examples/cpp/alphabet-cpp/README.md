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
```

**On Linux**:

```bash
g++ --debug -c -o build/alphabet.o cpp/alphabet.cpp -Wall -std=c++11 -Iinclude
```

Then on either platform, continue with:

```bash
ar rs build/libalphabet.a build/alphabet.o
ponyc --debug --export --output=build \
  --path=../../../../lib:../../../../lib/wallaroo/cpp_api/cpp/cppapi/build/build/lib:./build \
  alphabet-app
```

## Running

