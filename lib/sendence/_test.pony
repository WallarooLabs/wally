"""
# Sendence Standard Library

This package represents the unit test suite for Sendence's standard library.
Classes herein are used across applications rather than being specific to
just Wallaroo.

All tests can be run by compiling and running this package.
"""
use "ponytest"
use bytes = "bytes"
use container_queue = "container_queue"
use fix = "fix"
use fixed_queue = "fixed_queue"
use messages = "messages"
use queue = "queue"
use weighted = "weighted"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    bytes.Main.make().tests(test)
    container_queue.Main.make().tests(test)
    fix.Main.make().tests(test)
    fixed_queue.Main.make().tests(test)
    messages.Main.make().tests(test)
    queue.Main.make().tests(test)
    weighted.Main.make().tests(test)
