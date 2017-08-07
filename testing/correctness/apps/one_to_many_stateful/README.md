# One to Many Stateful Test App

This is a really simple, can be run by hand verification that taking one message and outputing more than one works. It takes in a string and from its single computation, it returns [string, " ", string, "\n"].

So if we send in "1" then "2" we should get:

```
1 1
2 2
```

## Setup

### Start a sink

nc -l 127.0.0.1 7002

### Start a single worker

./one_to_many_stateful -i 127.0.0.1:7010 -o 127.0.0.1:7002 -m 127.0.0.1:8000 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n worker-name

### Send 2 messages

giles/sender/sender -h 127.0.0.1:7010 -m 2 -s 300 -i 2_500_000
