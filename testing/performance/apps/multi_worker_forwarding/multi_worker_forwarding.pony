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
use "wallaroo"
use "wallaroo/core/common"
use "wallaroo_labs/mort"
use "wallaroo_labs/time"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/topology"

type InputBlob is Array[U8] val

actor Main
  new create(env: Env) =>
    try
      let pipeline = recover val
          let inputs = Wallaroo.source[InputBlob]("Input",
                TCPSourceConfig[InputBlob].from_options(InputBlobDecoder,
                  TCPSourceConfigCLIParser("InputBlobs", env.args)?))

          inputs
            .to[InputBlob](Identity[InputBlob])
            .to_sink(TCPSinkConfig[InputBlob].from_options(
              InputBlobEncoder, TCPSinkConfigCLIParser(env.args)?(0)?))
        end
      Wallaroo.build_application(env, "Multiworker Forwarding", pipeline)
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

primitive InputBlobDecoder is FramedSourceHandler[InputBlob]
  fun header_length(): USize => 4
  fun payload_length(data: Array[U8] iso): USize ? =>
    data.read_u32(0)?.bswap().usize()
  fun decode(data: Array[U8] val): InputBlob =>
    data

primitive Identity[A: Any val] is StatelessComputation[A, A]
  fun apply(input: A): A =>
    input

  fun name(): String => "Identity"

primitive PrintArray
  fun apply[A: Stringable #read](array: ReadSeq[A]): String =>
    """
    Generate a printable string of the contents of the given readseq to use in
    error messages.
    """
    "[len=" + array.size().string() + ": " + ", ".join(array.values()) + "]"


primitive InputBlobEncoder
  fun apply(t: Array[U8] val, wb: Writer = Writer): Array[ByteSeq] val =>
    wb.write(t)
    wb.u32_be(0) // fill out the header that was stripped in Decode
    wb.done()
    /*
    try
      wb.u64_be(t.read_u64(0)?.bswap()) //8
      wb.u64_be(0) //16
      wb.u128_be(0) // 32
      wb.u128_be(0) // 48
      wb.u128_be(0) // 64
      wb.u128_be(0) // 80
      wb.u128_be(0) // 96
      wb.u128_be(0) // 112
      wb.u128_be(0) // 128
      wb.done()
    else
      Fail()
      []
    end

*/
