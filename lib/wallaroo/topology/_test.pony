use "collections"
use "sendence/connemara"
use "sendence/equality"
use "wallaroo/boundary"
use "wallaroo/ent/data_receiver"
use "wallaroo/core"
use "wallaroo/metrics"
use "wallaroo/ent/network"
use "wallaroo/ent/recovery"
use "wallaroo/routing"

actor Main is TestList
  new create(env: Env) =>
    Connemara(env, this)

  new make() =>
    None

  fun tag tests(test: Connemara) =>
    _TestRouterEquality.make().tests(test)
    _TestStepSeqIdGenerator.make().tests(test)
