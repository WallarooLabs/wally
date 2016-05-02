# Dagon

A topology overlord. Boots components for you.

# Build
You will need [pony-stable](https://github.com/jemc/pony-stable)
to build the project. Compile and install it, then run these
commands.

Build dagon:
```
stable fetch
stable env ponyc --debug
```

Build dagon-child:
```
cd dagon-child
stable fetch
stable env ponyc --debug
cd ..
```

# Quickstart

```
./dagon-pony -f example.ini -h 127.0.0.1 -p 8080
```
