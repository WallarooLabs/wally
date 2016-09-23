use "buffered"
use "serialise"
use "net"
use "collections"

actor Main
  new create(env: Env) =>
    try
      let auth = env.root as AmbientAuth
      let builder: StepBuilder val = recover lambda(): Step tag => Step end end
      let builders: Array[StepBuilder val] val = recover [builder] end
      let t = LocalTopology(builders, 2)
      let a = Array[LocalTopology val]
      a.push(t)
      let msg = ChannelMsgEncoder.spin_up_local_topology(a(0), auth) 
      env.out.print("Ran!")
    else
      env.out.print("Error in Main")
    end

primitive ChannelMsgEncoder
  fun _encode(msg: ChannelMsg val, auth: AmbientAuth, 
    wb: Writer = Writer): Array[ByteSeq] val ? 
  =>
    let serialised: Array[U8] val =
      Serialised(SerialiseAuth(auth), msg).output(OutputSerialisedAuth(auth))
    let size = serialised.size()
    if size > 0 then
      wb.u32_be(size.u32())
      wb.write(serialised)
    end
    wb.done()

  fun spin_up_local_topology(local_topology: LocalTopology val, 
    auth: AmbientAuth): Array[ByteSeq] val ?
  =>
    _encode(SpinUpLocalTopologyMsg(local_topology), auth)

trait val ChannelMsg

class SpinUpLocalTopologyMsg is ChannelMsg
  let local_topology: LocalTopology val

  new val create(lt: LocalTopology val) =>
    local_topology = lt


class LocalTopology
  let _builders: Array[StepBuilder val] val
  let _local_sink: U64
  let _global_sink: Array[String] val

  new val create(bs: Array[StepBuilder val] val,
    local_sink: U64 = 0,
    global_sink: Array[String] val = recover Array[String] end) 
  =>
    _builders = bs
    _local_sink = local_sink
    _global_sink = global_sink

  fun builders(): Array[StepBuilder val] val =>
    _builders

  fun sink(): (Array[String] val | U64) =>
    if _local_sink == 0 then
      _global_sink
    else
      _local_sink
    end

actor Step
  be run[In: Any val](metric_name: String, source_ts: U64, input: In) =>
    @printf[I32]("Hi\n".cstring())

interface StepBuilder
  fun apply(): Step tag