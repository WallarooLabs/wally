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

use "buffered"
use "files"
use "serialise"
use "time"
use "wallaroo_labs/bytes"
use "wallaroo"
use "wallaroo_labs/mort"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/topology"

use "lib:reverse"

use @free[None](p: Pointer[U8])

use @GetComputationFunc[U64]()
use @GetEncodeFunc[U64]()
use @GetDecodeFunc[U64]()

use @CallComputationFunc[U64](computation_token: U64, data_token: U64)
use @CallDecodeFunc[U64](decoder_token: U64, p: Pointer[U8] tag, l: U64)
use @CallEncodeFunc[Pointer[U8] ref](encoder_token:U64, data_token: U64, size: Pointer[U64])

actor Main
  new create(env: Env) =>
    try
      let application = recover val
        Application("Raw Go Reverse App")
          .new_pipeline[U64, U64]("",
            TCPSourceConfig[U64].from_options(RawReverseDecoder(@GetDecodeFunc()),
              TCPSourceConfigCLIParser(env.args)?(0)?))
            .to[U64]({(): RawReverse => RawReverse(@GetComputationFunc())})
            .to_sink(TCPSinkConfig[U64].from_options(RawReverseEncoder(@GetEncodeFunc()),
              TCPSinkConfigCLIParser(env.args)?(0)?))?
      end
      Startup(env, application, "raw-reverse")
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

class val RawReverse is Computation[U64, U64]
  let _func_token: U64

  new val create(func_token: U64) =>
    _func_token = func_token

  fun apply(data_token: U64): U64 =>
    @CallComputationFunc(_func_token, data_token)

  fun name(): String => "Reverse"

class val RawReverseDecoder is FramedSourceHandler[U64]
  let _decoder_token: U64

  new val create(decoder_token: U64) =>
    _decoder_token = decoder_token

  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()

  fun decode(data: Array[U8] val): U64 =>
    @CallDecodeFunc(_decoder_token, data.cpointer(), data.size().u64())

class val RawReverseEncoder
  let _encoder_token: U64

  new val create(encoder_token: U64) =>
    _encoder_token = encoder_token

  fun apply(data_token: U64, wb: Writer): Array[ByteSeq] val =>
    var s: U64 = 0
    let r = recover val
      let e = @CallEncodeFunc(_encoder_token, data_token, addressof s)
      Array[U8].from_cpointer(e, s.usize()).clone()
    end
    wb.write(r)
    wb.done()
