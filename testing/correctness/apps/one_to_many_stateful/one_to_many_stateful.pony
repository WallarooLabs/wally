use "buffered"
use "serialise"
use "sendence/bytes"
use "wallaroo/"
use "wallaroo/fail"
use "wallaroo/state"
use "wallaroo/tcp_source"
use "wallaroo/topology"

actor Main
  new create(env: Env) =>
    try
      let application = recover val
        Application("One to Many App")
          .new_pipeline[String, String]("Pipeline", MyDecoder)
            .to_stateful[String, IgnoredState](ComputeIt,
              IgnoredStateBuilder, "ignored-state-builder")
            .to_sink(MyEncoder, recover [0] end)
      end
      Startup(env, application, None)
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

primitive ComputeIt
  fun name(): String => "ComputeIt"

  fun apply(input: String, sc_repo: StateChangeRepository[IgnoredState],
    state: IgnoredState): (Array[String] val, None)
  =>
    @printf[I32]("Computing it!\n".cstring())

    (recover val [input, " ", input, "\n"] end, None)

  fun state_change_builders():
    Array[StateChangeBuilder[IgnoredState] val] val
  =>
    recover Array[StateChangeBuilder[IgnoredState] val] end

primitive MyDecoder is FramedSourceHandler[String]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

  fun decode(data: Array[U8] val): String val =>
    String.from_array(data)

primitive MyEncoder
  fun apply(c: String, wb: Writer): Array[ByteSeq] val =>
    @printf[I32]("Got a result!\n".cstring())
    // Header
    wb.u32_be(c.size().u32())
    // Fields
    wb.write(c)
    wb.done()

class IgnoredState is State

primitive IgnoredStateBuilder
  fun name(): String => "IgnoredStateBuilder"
  fun apply(): IgnoredState => IgnoredState
