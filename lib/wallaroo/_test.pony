"""
# Wallaroo Standard Library

This package represents the unit test suite for Wallaroo.

All tests can be run by compiling and running this package.
"""
use "sendence/connemara"
use cluster_manager = "cluster_manager"
use data_channel = "data_channel"
use initialization = "initialization"
use rebalancing = "rebalancing"
use routing = "routing"
use spike = "spike"
use topology = "topology"

actor Main is TestList
  new create(env: Env) =>
    Connemara(env, this)

  new make() =>
    None

  fun tag tests(test: Connemara) =>
    cluster_manager.Main.make().tests(test)
    data_channel.Main.make().tests(test)
    initialization.Main.make().tests(test)
    rebalancing.Main.make().tests(test)
    routing.Main.make().tests(test)
    spike.Main.make().tests(test)
    topology.Main.make().tests(test)
