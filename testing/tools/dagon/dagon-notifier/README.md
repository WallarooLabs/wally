# Dagon Notifier

A process used to send external messages to Dagon.

##Build
You will need [pony-stable](https://github.com/ponylang/pony-stable)
to build the project. Compile and install it, then run these
commands.

Build dagon-notifier:
```
stable fetch
stable env ponyc --debug
```

## Quickstart
dagon-notifier takes two arguments:
```
-d ip address of running dagon process
-m a string that converts to an encoded external messge
```

## Available String -> ExternalMsg conversions
`StartGilesSenders` -> `_StartGilesSenders`
