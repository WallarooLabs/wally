# Resilience Basics 

When a Wallaroo application runs with resilience, we keep track of the state changes 
that occur within the system, as well as the messages that were sent over 
boundaries between workers. If a worker dies and is restarted, Wallaroo will 
recover its state and replay any messages that were not successfully processed 
before the worker died. In other words, from a state and message processing 
perspective, it's as though the worker never went down.

## Enabling Resilience

In order to run Wallaroo with resilience, you need to compile your application with the 
following compiler argument:

```bash
-D resilience
```

This means the full command to compile with resilience will be:

```bash
make PONYCFLAGS="-D resilience"
```

When running a resilience-enabled Wallaroo app, you can optionally specify the 
target directory for resilience files via the `--resilience-dir` parameter 
(default is `/tmp`). Keep in mind that these files will grow into the gigabytes.

## API

## Guarantees


