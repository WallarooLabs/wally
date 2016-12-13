"""
1) just source:
./just-source -i 127.0.0.1:7000 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n node-name --ponythreads=4 --ponynoblock

2) orders:
giles/sender/sender -b 127.0.0.1:7000 -m 5000000 -s 300 -i 5_000_000 -f demos/marketspread/350k-orders-fixish.msg -r --ponythreads=1 -y -g 57 -w
"""

use "assert"
use "buffered"
use "collections"
use "net"
use "options"
use "time"
use "sendence/bytes"
use "sendence/fix"
use "sendence/hub"
use "sendence/new-fix"
use "sendence/wall-clock"
use "wallaroo"
use "wallaroo/fail"
use "wallaroo/metrics"
use "wallaroo/tcp-source"
use "wallaroo/topology"

actor Main
  new create(env: Env) =>
    try
      let application = recover val
        Application("Just Source")
          .new_pipeline[FixOrderMessage val, None](
            "Orders", FixOrderFrameHandler)
            .to[FixOrderMessage val](FilterBuilder[FixOrderMessage val])
            .done()
      end
      Startup(env, application, "just-source")
    else
      env.out.print("Couldn't build topology")
    end

primitive Filter[In: Any val]
  fun name(): String => "filter"
  fun apply(r: In): None =>
    None

primitive FilterBuilder[In: Any val]
  fun apply(): Computation[In, In] val =>
    Filter[In]

primitive FixOrderFrameHandler is FramedSourceHandler[FixOrderMessage val]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

  fun decode(data: Array[U8] val): FixOrderMessage val ? =>
    match FixishMsgDecoder(data)
    | let m: FixOrderMessage val => m
    | let m: FixNbboMessage val => @printf[I32]("Got FixNbbo\n".cstring()); Fail(); error
    else
      @printf[I32]("Could not get FixOrder from incoming data\n".cstring())
      @printf[I32]("data size: %d\n".cstring(), data.size())
      error
    end
