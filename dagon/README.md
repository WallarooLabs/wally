# Dagon

A topology overlord. Boots components for you.

## Build
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

## Quickstart
dagon-pony takes four arguments:
```
-t time in seconds to wait for processing to finish after Giles
   Sender is done
-e giles-receiver will terminate early if it receives all of the messages
   it is expecting.
   If no 'expect' is specified for giles-receiver in the ini section,
   Dagon behaves as if it wasn't invoked with '-e'
-f configuration file path
-h host ip address dagon should listen on
```

Example:
```
./dagon -t 10 -e -f double-divide.ini -h 127.0.0.1:8080
```
