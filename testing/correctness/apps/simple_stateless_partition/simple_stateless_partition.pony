"""
This app demonstrates a stateless partition where all data ends up
at a computation after the partition which prints "Finished processing x",
where x is the value of the U64 that entered the system.

1. Worker 1:
```bash
./simple_stateless_partition -i 127.0.0.1:7000 -o 127.0.0.1:7001 \
-m 127.0.0.1:5001 -c 127.0.0.1:6002 -d 127.0.0.1:6004 -w 2 -t
```

2. Worker 2:
```bash
./simple_stateless_partition -i 127.0.0.1:7000 -o 127.0.0.1:7001 \
-m 127.0.0.1:5001 -c 127.0.0.1:6002 -d 127.0.0.1:6004 -n worker2 -w 2
```

3. Sender
```bash
../../../../giles/sender/sender -h 127.0.0.1:7000 -s 100 -i 50_000_000 \
--ponythreads=1 -y -g 12 -w -u -m 10000
```
"""
use "buffered"
use "options"
use "serialise"
use "sendence/bytes"
use "wallaroo"
use "wallaroo/fail"
use "wallaroo/source"
use "wallaroo/tcp_source"
use "wallaroo/topology"

actor Main
  new create(env: Env) =>
    try
      let application =
        recover val
          Application("Simple Stateless Partition")
            .new_pipeline[U64, None]("IdentityPrint Pipeline",
              TCPSourceConfig[U64].from_options(U64FramedHandler,
              TCPSourceConfigCLIParser(env.args)(0)) where coalescing = false)
              .to_parallel[U64]({(): IdentityPrint => IdentityPrint})
              .to[None]({(): EndOfLine => EndOfLine})
              .done()
        end
      Startup(env, application, "simple-stateless-partition")
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

primitive IdentityPrint is Computation[U64, U64]
  fun apply(input: U64): U64 =>
    @printf[I32]("Rcvd -> %s\n".cstring(), input.string().cstring())
    input

  fun name(): String => "IdentityPrint"

primitive EndOfLine is Computation[U64, None]
  fun apply(input: U64): None =>
    @printf[I32]("Finished processing %s\n".cstring(),
      input.string().cstring())

  fun name(): String => "EndOfLine"

primitive U64FramedHandler is FramedSourceHandler[U64]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

  fun decode(data: Array[U8] val): U64 ? =>
    Bytes.to_u64(data(0), data(1), data(2), data(3),
      data(4), data(5), data(6), data(7))
