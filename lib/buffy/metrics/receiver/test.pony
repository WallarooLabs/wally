use "ponytest"
use "collections"
use "promises"
use "buffy/messages"
use "sendence/bytes"
use "debug"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make(env: Env) => None

  fun tag tests(test: PonyTest) =>
    test(_TestMetricsReceiver)


class iso _TestMetricsReceiver is UnitTest
  fun name(): String => "buffy:TestMetricsReceiver"

  fun apply(h: TestHelper) =>
    true
