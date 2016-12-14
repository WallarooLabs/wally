"""
# Wallaroo Standard Library

This package represents the unit test suite for Wallaroo.

All tests can be run by compiling and running this package.
"""
use "ponytest"
use routing = "routing"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    routing.Main.make().tests(test)
