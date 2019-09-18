/*

Copyright 2019 The Wallaroo Authors.

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
use "options"
use "wallaroo"
use "wallaroo/core/common"
use "wallaroo_labs/logging"
use "wallaroo_labs/mort"
use "wallaroo/core/sink/connector_sink"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/connector_source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/state"
use "wallaroo_labs/time"
use "wallaroo/core/topology"

type InputBlob is Array[U8] val

actor Main
  new create(env: Env) =>
    Log.set_defaults()

    let default_par_factor: USize = 64
    var par_factor = default_par_factor
    let help = "<Wallaroo args, see below> [--help] [--verbose] [--parallelism] [--source-decoder framed|unframed] --source tcp|connector [--key-by first-byte|random] [--step asis|asis-state|noop]* [--sink-parallelism] --sink tcp|connector"
    var verbose: Bool = false
    var source_decoder: FramedSourceHandler[InputBlob] val =
      recover val InputBlobDecoder end

    try
      let pipeline = recover val
        var source = recover ref
          var src: (Pipeline[InputBlob] | None) = None
          par_factor = default_par_factor
          for o in recover ref make_options(env.args) end do
            match o
            | ("help", let arg: None) =>
              @printf[I32]("Usage: $0 %s\n".cstring(), help.cstring())
              StartupHelp()
              Fail()
            | ("verbose", None) =>
              verbose = true
            | ("parallelism", let p: U64) =>
              par_factor = p.usize()
            | ("source-decoder", let sd: String) =>
              match sd
                | "framed" =>
                  source_decoder = recover val InputBlobDecoder end
                | "unframed" =>
                  source_decoder = recover val UnframedGreedyDecoder end
                else
                  @printf[I32]("Unknown source decoder: %s\n".cstring(),
                    sd.cstring())
                  Fail()
                end
            | ("source", let st: String) =>
              match st
              | "tcp" =>
                src = Wallaroo.source[InputBlob]("Input",
                  TCPSourceConfig[InputBlob].from_options(source_decoder,
                    TCPSourceConfigCLIParser("InputBlobs", env.args)?
                    where parallelism' = par_factor))
              | "connector" =>
                src = Wallaroo.source[InputBlob]("Input",
                  ConnectorSourceConfig[InputBlob].from_options(
                    source_decoder,
                    ConnectorSourceConfigCLIParser("InputBlobs", env.args)?
                    where parallelism' = par_factor))
              else
                @printf[I32]("Unknown source type: %s\n".cstring(), st.cstring())
                Fail()
              end
              if verbose then
                @printf[I32]("source type: %s, parallelism = %lu\n".cstring(),
                  st.cstring(), par_factor)
              end
            // There are lots of Wallaroo-specific flags that will
            // be caught by a ParseError clause ... so omit that clause.
            end
          end
          (src as Pipeline[InputBlob])
        end

        par_factor = default_par_factor
        for o in recover ref make_options(env.args) end do
          match o
          | ("parallelism", let p: U64) =>
            par_factor = p.usize()
          | ("key-by", let kb: String) =>
            match kb
            | "first-byte" =>
              source = source.key_by(FirstByte)
            | "random" =>
              source = source.key_by(KeyByRandomly)
            else
              @printf[I32]("Unknown key-by: %s\n".cstring(), kb.cstring())
              Fail()
            end
            if verbose then
              @printf[I32]("key by: %s\n".cstring(), kb.cstring())
            end
          | ("step", let stg: String) =>
            match stg
            | "asis" =>
              source = source.to[Array[U8] val](
                AsIsC where parallelism = par_factor)
            | "asis-state" =>
              source = source.to[Array[U8] val](
                AsIsStateC where parallelism = par_factor)
            | "noop" =>
              source = source.to[Array[U8] val](
                NoOp where parallelism = par_factor)
            else
              @printf[I32]("Unknown step: %s\n".cstring(), stg.cstring())
              Fail()
            end
            if verbose then
              @printf[I32]("step: %s, parallelism = %lu\n".cstring(),
                stg.cstring(), par_factor)
            end
          end
        end

        par_factor = 1 // Reset for typical default for sink
        for o in recover ref make_options(env.args) end do
          match o
          | ("sink-parallelism", let p: U64) =>
            par_factor = p.usize()
          | ("sink", let sk: String) =>
            if verbose then
              @printf[I32]("sink parallelism: %lu\n".cstring(), par_factor)
            end
            match sk
            | "tcp" =>
              source = source
                .to_sink(TCPSinkConfig[InputBlob].from_options(
                  OutputBlobEncoder,
                  TCPSinkConfigCLIParser(env.args)?(0)?)
                  where parallelism = 1 /*** par_factor ***/)
            | "connector" =>
              source = source
                .to_sink(ConnectorSinkConfig[InputBlob].from_options(
                  OutputBlobEncoder,
                  ConnectorSinkConfigCLIParser(env.args)?(0)?)
                  where parallelism = par_factor)
            else
              @printf[I32]("Unknown sink: %s\n".cstring(), sk.cstring())
              Fail()
            end
            if verbose then
              @printf[I32]("sink: %s, parallelism = %lu\n".cstring(),
                sk.cstring(), par_factor)
            end
          end
        end

        source
      end

      Wallaroo.build_application(env, "Passthrough", pipeline)
    else
      @printf[I32]("Couldn't build topology\n".cstring())
      @printf[I32]("Run with --help flag for usage summary\n".cstring())
      //@printf[I32]("Usage: $0 %s\n".cstring(), help.cstring())
      //StartupHelp()
      Fail()
    end

  fun make_options(args: Array[String val] val): Options iso^ =>
    let o = recover iso
      Options(args, false)
        // General flags
        .add("help", None)
        .add("verbose", None, None, Optional)
        .add("parallelism", None, U64Argument, Optional)
        // Source-specific flags
        .add("source-decoder", None, StringArgument, Optional)
        // Sink-specific flags
        .add("sink-parallelism", None, U64Argument, Optional)
        // Pipeline flags
        .add("source", None, StringArgument, Required)
        .add("key-by", None, StringArgument, Optional)
        .add("step", None, StringArgument, Optional)
        .add("sink", None, StringArgument, Required)
    end
    consume o

primitive FirstByte
  fun apply(input: Array[U8] val): Key =>
    if input.size() > 0 then
      try
        String.from_array([input(0)?])
      else
        Fail()
        ""
      end
    else
      ""
    end

primitive KeyByRandomly
  fun apply(input: Any): Key =>
    String.from_array([ @ponyint_cpu_tick[U64]().u8() ])

primitive NoOp is StatelessComputation[Array[U8] val, I8]
  fun name(): String => "NoOp"

  fun apply(input: Array[U8] val): (I8 | None) =>
    @printf[I32]("NoOp: top\n".cstring())
    None

primitive AsIsC is StatelessComputation[Array[U8] val, Array[U8] val]
  fun name(): String => "AsIs computation"

  fun apply(input: Array[U8] val): (Array[U8] val | None) =>
    @printf[I32]("AsIsC: got input of %d bytes\n".cstring(), input.size())
    input

class AsIsState is State
  var count: USize = 0

primitive AsIsStateC is StateComputation[Array[U8] val, Array[U8] val, AsIsState]
  fun name(): String => "AsIsState computation"

  fun apply(input: Array[U8] val, state: AsIsState): (Array[U8] val | None) =>
    state.count = state.count + 1
    @printf[I32]("AsIsStateC: got input of %lu bytes, count %lu\n".cstring(), input.size(), state.count)
    input

  fun initial_state(): AsIsState =>
    AsIsState


primitive InputBlobDecoder is FramedSourceHandler[InputBlob]
  fun header_length(): USize => 4
  fun payload_length(data: Array[U8] iso): USize ? =>
    data.read_u32(0)?.bswap().usize()
  fun decode(data: Array[U8] val): InputBlob =>
    data

primitive UnframedGreedyDecoder is FramedSourceHandler[InputBlob]
  fun header_length(): USize => 0
  fun payload_length(data: Array[U8] iso): USize =>
    16384 // this doesn't matter currently, header = 0
    // means we read as much as possible off socket
  fun decode(data: Array[U8] val): InputBlob =>
    data

primitive PrintArray
  fun apply[A: Stringable #read](array: ReadSeq[A]): String =>
    """
    Generate a printable string of the contents of the given readseq to use in
    error messages.
    """
    "[len=" + array.size().string() + ": " + ", ".join(array.values()) + "]"


primitive OutputBlobEncoder
  fun apply(t: Array[U8] val, wb: Writer = Writer): Array[ByteSeq] val =>
    wb.write(t)
    wb.done()
