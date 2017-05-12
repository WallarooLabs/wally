use "buffered"
use "random"
use "collections"

class SpewerConfig
  let host: String
  let port: String
  let count: USize

  new create(host': String, port': String, count': USize) =>
    host = host'
    port = port'
    count = count'

actor SpewerApp
  let _env: Env
  new create(env: Env) =>
    _env = env
    let config = parse_config(env.args)
    env.err.print("host: " + config.host)
    env.err.print("port: " + config.port)
    env.err.print("count: " + config.count.string())
    Spewer(config.host, config.port, config.count, env.out, this)

  be report_sum(sum: U64) =>
    _env.err.print("final sum = " + sum.string())

  fun parse_config(args: Array[String] val): SpewerConfig =>
    try
      SpewerConfig(args(2), args(3), args(4).usize())
    else
      SpewerConfig("127.0.0.1", "7002", 100_000_000)
    end

primitive RandomMessageGenerator
  fun apply(max_size: USize, min_value: U32, max_value: U32, mt: MT): (Array[U32] val, U32) =>
    let size = (mt.next().usize() % max_size) + 1
    // let elements: Array[U32] iso = recover Array[U32].undefined(size) end
    let elements: Array[U32] iso = recover Array[U32] end
    var sum: U32 = 0
    for i in Range(0, size) do
      let value = min_value + (mt.next().u32() % max_value)
      sum = sum + value
      elements.push(value)
    end
    (consume elements, sum)

primitive MessageGenerator
  fun apply(elements: Array[U32] val, writer: Writer): Array[ByteSeq] val =>
    let message_size: USize = 2 + // element count
      (4 * elements.size()) // element bytes
    writer.u16_be(message_size.u16())
    writer.u16_be(elements.size().u16())
    for e in elements.values() do
      writer.u32_be(e)
    end
    writer.done()

actor Spewer
  new create(host: String, port: String, count: USize, out: OutStream, spewer_app: SpewerApp) =>
    let mt = MT
    let writer: Writer = Writer
    var total: U64 = 0
    for i in Range(0, count) do
      (let message, let sum) = RandomMessageGenerator(5, 0, 8, mt)
      total = total + sum.u64()
      out.writev(MessageGenerator(message, writer))
    end
    spewer_app.report_sum(total)