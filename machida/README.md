# Machida

Machida is a Wallaroo-Python Runtime that enables a Wallaroo application to be written in Python.

## Requirements
- clang
- python-dev
- sendence-ponyc
- giles-sender

## Build

Create the `build` directory if it doesn't already exist.

```
mkdir build
```

Build the program.

```
clang -g -o build/python-wallaroo.o -c cpp/python-wallaroo.c
ar rvs build/libpython-wallaroo.a build/python-wallaroo.o
ponyc --debug --output=build --path=build --path=../lib/ .
```

## Run Reverse Word (stateless computation)

See [Reverse application instructions](/book/examples/python/reverse/README.md).

## Run Alphabet (stateful computation)

See [Alphabet application instructions](/book/examples/python/alphabet/README.md).

## Run Marketspread (stateful computation)

See [Market Spread application instructions](/book/examples/python/market_spread/README.md)
