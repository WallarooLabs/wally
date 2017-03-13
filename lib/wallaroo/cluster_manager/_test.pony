use "ponytest"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    TestDockerSwarmClusterManager.make().tests(test)
    TestThroughputBasedClusterGrowthTrigger.make().tests(test)
