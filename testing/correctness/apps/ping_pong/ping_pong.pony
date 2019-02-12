/*

Copyright 2017 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

"""
This app provides an example of two separate running Wallaroo apps
that are connected sink-to-source (forming a closed circle between
them). There is no need to set up any external data listeners.

Run Ping:
./ping_pong -i 127.0.0.1:7000 -o 127.0.0.1:7001 -m 127.0.0.1:5001 -c 127.0.0.1:6002 -d 127.0.0.1:6004 -n node-name --ping -t

Run Pong:
./ping_pong -i 127.0.0.1:7001 -o 127.0.0.1:7000 -m 127.0.0.1:5001 -c 127.0.0.1:6012 -d 127.0.0.1:6014 -n node-name --pong -t

Send 1 message into Ping:
../../../../giles/sender/sender -h 127.0.0.1:7000 -y -g 12 -w -u -m 1
"""
use "buffered"
use "options"
use "serialise"
use "wallaroo_labs/bytes"
use "wallaroo"
use "wallaroo_labs/mort"
use "wallaroo_labs/time"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/topology"

primitive Ping
primitive Pong

actor Main
  new create(env: Env) =>
    var app_type: (Ping | Pong | None) = None
    var options = Options(env.args, false)

    options
      .add("ping", None)
      .add("pong", None)

    for option in options do
      match option
      | ("ping", None) => app_type = Ping
      | ("pong", None) => app_type = Pong
      end
    else
      Fail()
    end

    try
      let pipeline =
        recover val
          match app_type
          | Ping =>
            Wallaroo.source[U8]("Ping",
              TCPSourceConfig[U8].from_options(PongDecoder,
                TCPSourceConfigCLIParser("Ping", env.args)?))
              .to[U8](Pingify)
              .to_sink(TCPSinkConfig[U8].from_options(PingPongEncoder,
                TCPSinkConfigCLIParser(env.args)?(0)?))
          | Pong =>
            Wallaroo.source[U8]("Pong",
              TCPSourceConfig[U8].from_options(PingDecoder,
                TCPSourceConfigCLIParser("Pong", env.args)?))
              .to[U8](Pongify)
              .to_sink(TCPSinkConfig[U8].from_options(PingPongEncoder,
                TCPSinkConfigCLIParser(env.args)?(0)?))
          else
            @printf[I32]("Use --ping or --pong to start app.\n".cstring())
            error
          end
        end

      match app_type
      | Ping =>
        @printf[I32]("Starting up as Ping\n".cstring())
        Wallaroo.build_application(env, "Ping", pipeline)
      | Pong =>
        @printf[I32]("Starting up as Pong\n".cstring())
        Wallaroo.build_application(env, "Pong", pipeline)
      end
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

primitive Pingify is StatelessComputation[U8, U8]
  fun apply(input: U8): U8 =>
    @printf[I32]("Rcvd Pong -> %s\n".cstring(), input.string().cstring())
    1

  fun name(): String => "Pingify"

primitive Pongify is StatelessComputation[U8, U8]
  fun apply(input: U8): U8 =>
    @printf[I32]("Rcvd Ping -> %s\n".cstring(), input.string().cstring())
    0

  fun name(): String => "Pongify"

primitive PingDecoder is FramedSourceHandler[U8]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()

  fun decode(data: Array[U8] val): U8 ? =>
    if data(0)? == 1 then 1 else error end

primitive PongDecoder is FramedSourceHandler[U8]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()

  fun decode(data: Array[U8] val): U8 ? =>
    if data(0)? == 0 then 0 else error end

primitive PingPongEncoder
  fun apply(byte: U8, wb: Writer): Array[ByteSeq] val =>
    wb.u32_be(1)
    wb.u8(byte)
    wb.done()
