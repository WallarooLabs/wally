"""
# Sendence Standard Library

This package represents the unit test suite for Sendence's standard library.
Classes herein are used across applications rather than being specific to
just Wallaroo.

All tests can be run by compiling and running this package.
"""
use "sendence/connemara"
use bytes = "bytes"
use container_queue = "container_queue"
use fix = "fix"
use messages = "messages"
use options = "options"
use queue = "queue"
use weighted = "weighted"

actor Main is TestList
  new create(env: Env) =>
    Connemara(env, this)

  new make() =>
    None

  fun tag tests(test: Connemara) =>
    bytes.Main.make().tests(test)
    container_queue.Main.make().tests(test)
    fix.Main.make().tests(test)
    messages.Main.make().tests(test)
    options.Main.make().tests(test)
    queue.Main.make().tests(test)
    weighted.Main.make().tests(test)
