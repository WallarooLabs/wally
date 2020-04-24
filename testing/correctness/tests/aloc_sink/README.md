
# CircleCI testing for aloc_sink and Wallaroo sink 2PC protocol

The aloc_sink tests in this directory test both `aloc_sink`'s and Wallaroo's reactions to 2PC protocol failures and also TCP connection failures that are injected artificially during test runs.

See the file [README.abort-rules.md](README.abort-rules.md) for details on how `aloc_sink` can be configured for fault injection.

## Separate tests vs. a single test with multiple components

The 2PC round number is embedded in the 2PC transaction ID string.  `aloc_sink` knows about the string's formatting convention and can extract the 2PC round number out of the txn ID string.

Early aloc_sink tests would use a single test to detect problems with multiple 2PC failures (via fault injection by `aloc_sink`).  As the 2PC implementation of Wallaroo had evolved in late 2019-early 2020, it became impossible for the test to determine exactly which 2PC round numbers would be issued by Wallaroo.

The single large test was split into several smaller tests that are run serially by the `Makefile`.  Currently, it is 6 tests.  Each test uses a different abort rule config file (see [README.abort-rules.md](README.abort-rules.md) for more detail), and each test invocation expects either a 2PC COMMIT or ABORT in response to a specific fault.  Each test has only a single fault injected.

# Manual testing for aloc_sink and overall end-to-end 2PC correctness

End-to-end testing means:

    connector source process -> Wallaroo -> `aloc_sink` connector sink process

This test is not yet automated.  See the [testing/correctness/scripts/effectively-once](../../scripts/effectively-once) directory for details on manual testing of end-to-end 2PC correctness.

