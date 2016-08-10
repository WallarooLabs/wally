use "ponytest"
use "collections"
use "buffy/messages"
use "sendence/bytes"
use "json"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make(env: Env) => None

  fun tag tests(test: PonyTest) =>
//    test(_TestMonitoringHubEncoder)
    test(_TestTimeline)

class iso _TestTimeline is UnitTest
  fun name(): String => "buffy:Timeline"

  fun apply(h: TestHelper) ? =>
    let tl = Timeline("test", "step", 1_000_000_000)
    let base: U64 = 1469658500_000000001
    let ceil: U64 = base + 10_000_000_000
    for v in Range[U64](base, ceil, 100_000_000) do
      for v' in Range[U64](0, 1_000_000_000, 1_000_000) do
        tl(v, v+v')
      end
    end

    let j = tl.json()
    h.assert_eq[I64](((((j.data(j.data.size()-1) as JsonObject)
      .data("topics") as JsonObject)
      .data("latency_bins") as JsonObject)
      .data("29") as I64), 2680)
    true

class iso _TestMonitoringHubEncoder is UnitTest
  fun name(): String => "buffy:MonitoringHubEncoder"

  fun apply(h: TestHelper) ? =>
    h.long_test(1_000_000_000)
    let auth: AmbientAuth = h.env.root as AmbientAuth
    let app_name = "test app"


class LengthParser is Iterator[String]
  let _data: Array[U8 val] val
  var _idx: USize = 0

  new create(data: Array[U8 val] val) =>
    _data= data

  fun ref has_next(): Bool =>
    _idx <= _data.size()

  fun ref next(): String val ? =>
    let s = _idx = _idx + 4
    let slc = _data.slice(s, _idx)
    var chunk = bytes_to_usize(slc)
    let s' = _idx = _idx + chunk
    let slc' = _data.slice(s', _idx).clone()
    String.create().append(slc').clone()

  fun tag bytes_to_usize(a: Array[U8 val] ref): USize ? =>
    ((a(0).u32() << 24) + (a(1).u32() << 16) + (a(2).u32() << 8) +
    a(3).u32()).usize()

