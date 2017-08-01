use "sendence/connemara"
use "wallaroo/topology"

actor Main is TestList
  new create(env: Env) =>
    Connemara(env, this)

  new make() =>
    None

  fun tag tests(test: Connemara) =>
    TestWatermarker.make().tests(test)
    TestWatermarking.make().tests(test)
