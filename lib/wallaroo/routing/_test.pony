use "ponytest"

use "wallaroo/topology"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    TestWatermarking.make().tests(test)
