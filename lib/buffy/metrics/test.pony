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
    test(_TestTimeline)

class iso _TestTimeline is UnitTest
  fun name(): String => "buffy:Timeline"

  fun apply(h: TestHelper) ? =>
    let tl = Timeline(1234, "test", "step", 1_000_000_000)
    let base: U64 = 1469658500_000000001
    let ceil: U64 = base + 10_000_000_000
    for v in Range[U64](base, ceil, 100_000_000) do
      for v' in Range[U64](0, 1_000_000_000, 1_000_000) do
        tl(v, v+v')
      end
    end

    // Make sure we've got 11 periods in timeline
    h.assert_eq[USize](tl.size(), 11)
    // Verify the JSON output structure
    let j = tl.json()
    h.assert_eq[USize](j.data.size(), 11)
    h.assert_eq[I64](((((j.data(10) as JsonObject)
      .data("topics") as JsonObject)
      .data("latency_bins") as JsonObject)
      .data("29") as I64), 2680)

    true

