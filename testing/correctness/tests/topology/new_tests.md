# Wallaroo Topology Layout Tests

This section tests Wallaroo topology layouts. Its purpose is to:
1. verify that known topologies work, and continue to work as we make changes to the core of Wallaroo.
2. identify topology layouts that do not work, so that we can fix them and add them to the test above.

The testing is done via integration testing:
1. a topology is specified
2. that topology is described in an application
3. the application is run (with 1,2,3) workers, input is sent in, and output is validated to match an expectation.

The spec generation is done manually for now.
It is not easy to come up with a set of computations from which we can derive validation logic, given a known input set, that we can use to validate outputs.


## Generative Topology Tests
As per the above, we do not generate all possible types at the moment. However, we do aim to generate the basic matrix of combinations, so that we can add API entries (pony, machida, machida3, go, etc.) to it without having to duplicate too much code or compile a very large number of applications.

### Computations List
Types of computations we need to test

- stateless comp
- state comp
- parallel comp
- partitioned state comp

Their API build methods are:
- to
- to_stateful
- to_parallel
- to_state_partition

tests:
   4: {apis}
  16: {apis} x {apis}
  64: {apis} x {apis} x {apis}

### Flow Modifiers
Types of flow modifiers we need to test (as computations)

- 1:1
- 1:<1 (filtered)
- 1:>1 (OneToMany)

tests:
  {apis} x {flows}
  {flows} x {apis}

### Topologies
Types of topologies

- single
- double, parallel stream (no intersection)
- double, intersecting stream
- ?

## Testing
For now, we aim to have every permutation of 1, and 2 computations in single stream apps.
This means, for example, if we had a base set of {a,b,c}, we would produce the following topologies:

    a
    aa
    ab
    ac
    b
    ba
    bb
    bc
    c
    ca
    cb
    cc

