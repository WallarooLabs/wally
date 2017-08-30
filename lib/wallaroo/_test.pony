"""
# Wallaroo Standard Library

This package represents the unit test suite for Wallaroo.

All tests can be run by compiling and running this package.
"""
use "sendence/connemara"
use broadcast = "ent/w_actor/broadcast"
use cluster_manager = "ent/cluster_manager"
use data_channel = "data_channel"
use initialization = "initialization"
use rebalancing = "ent/rebalancing"
use recovery = "ent/recovery"
use spike = "spike"
use topology = "topology"
use watermarking = "ent/watermarking"

actor Main is TestList
  new create(env: Env) =>
    Connemara(env, this)

  new make() =>
    None

  fun tag tests(test: Connemara) =>
    broadcast.Main.make().tests(test)
    cluster_manager.Main.make().tests(test)
    data_channel.Main.make().tests(test)
    initialization.Main.make().tests(test)
    rebalancing.Main.make().tests(test)
    recovery.Main.make().tests(test)
    spike.Main.make().tests(test)
    topology.Main.make().tests(test)
    watermarking.Main.make().tests(test)
