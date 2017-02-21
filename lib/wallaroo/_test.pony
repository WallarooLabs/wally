"""
# Wallaroo Standard Library

This package represents the unit test suite for Wallaroo.

All tests can be run by compiling and running this package.
"""
use "ponytest"
use initialization = "initialization"
use routing = "routing"
use spike = "spike"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    initialization.Main.make().tests(test)
    routing.Main.make().tests(test)
    spike.Main.make().tests(test)
