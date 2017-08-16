use "sendence/connemara"

actor Main is TestList
  new create(env: Env) =>
    Connemara(env, this)

  new make() =>
    None

  fun tag tests(test: Connemara) =>
    _TestDockerSwarmClusterManager.make().tests(test)
    _TestThroughputBasedClusterGrowthTrigger.make().tests(test)
