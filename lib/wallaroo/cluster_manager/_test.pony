use "sendence/connemara"

actor Main is TestList
  new create(env: Env) =>
    Connemara(env, this)

  new make() =>
    None

  fun tag tests(test: Connemara) =>
    TestDockerSwarmClusterManager.make().tests(test)
    TestThroughputBasedClusterGrowthTrigger.make().tests(test)
