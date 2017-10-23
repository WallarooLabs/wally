# Raw Reverse

This program will take an input string (32-bit framed) and produce a reversed string (32-bit framed). The decoder, reverse computation, and encoder will be implemented in Go.

## Application

The application topology looks like this:

```
-framed string-> [decoder] -string-> [reverse] -string-> [encoder] -framed string->
   TCP                                                                 TCP
```

### Input and Output

The input and output are strings framed by 32-bit big-endian headers.

## Build

In order to build this application, you must first build the Go library, then build the Wallaroo application.

```
go build -buildmode=c-archive -o build/libreverse.a libreverse.go
stable env ponyc
```

## Run

You will need four shells to run this application.

### Shell 1

Run the listener

```
nc -l 127.0.0.1 7002 > reverse.out
```

### Shell 2

Run the application

```
./raw-reverse --in 127.0.0.1:7010 --out 127.0.0.1:7002 --metrics 127.0.0.1:5001 \
  --control 127.0.0.1:12500 --data 127.0.0.1:12501 --external 127.0.0.1:5050 \
  --cluster-initializer --ponynoblock --ponythreads=1
```

### Shell 3

Send data to the application.

```
echo -n '\x00\x00\x00\x04abcd' | nc 127.0.0.1 7010
```

### Shell 4

After you send some data you can look at the `reverse.out` file using `hexdump`.

```
hexdump -C reverse.out
```

You should see something like this:

```
00000000  00 00 00 04 64 63 62 61  00 00 00 04 64 63 62 61  |....dcba....dcba|
00000010
```
