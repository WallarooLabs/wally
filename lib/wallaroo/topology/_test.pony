use "collections"
use "sendence/connemara"
use "sendence/equality"
use "wallaroo/boundary"
use "wallaroo/metrics"
use "wallaroo/network"
use "wallaroo/recovery"
use "wallaroo/routing"

actor Main is TestList
  new create(env: Env) =>
    Connemara(env, this)

  new make() =>
    None

  fun tag tests(test: Connemara) =>
    _TestRouterEquality.make().tests(test)
    _TestStepSeqIdGenerator.make().tests(test)
