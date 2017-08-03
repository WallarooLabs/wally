use "sendence/connemara"

actor Main is TestList
  new create(env: Env) =>
    Connemara(env, this)

  new make() =>
    None

  fun tag tests(test: Connemara) =>
    TestThroughputBasedClusterGrowthTrigger.make().tests(test)
