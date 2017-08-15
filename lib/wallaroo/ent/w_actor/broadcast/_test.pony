use "sendence/connemara"

use "wallaroo/topology"

actor Main is TestList
  new create(env: Env) =>
    Connemara(env, this)

  new make() =>
    None

  fun tag tests(test: Connemara) =>
    _TestVectorTimestamp.make().tests(test)
    _TestExternalBroadcastVariableUpdater.make().tests(test)
