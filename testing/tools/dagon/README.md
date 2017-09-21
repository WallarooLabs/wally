# Dagon

A topology overlord. Boots components for you.

## Build
You will need [pony-stable](https://github.com/ponylang/pony-stable)
to build the project. Compile and install it, then run these
commands.

Build `dagon` and `dagon-child`:
```
make debug=true
```

## Quickstart
`dagon` takes four arguments:
```
-t time in seconds to wait for processing to finish after Giles
   Sender is done
-f configuration file path
-h host ip address dagon should listen on
-D delays the start of Giles Senders
```

Example:
```
./dagon -t 10 -f double-divide.ini -h 127.0.0.1:8080
```
