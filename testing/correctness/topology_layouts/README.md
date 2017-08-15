# Topology Layouts Integration Tests

The purpose of the included tests is to verify that applications with a given topology structure both build and run as expected.

They are built and run with a given input and verified against an expected output as part of our CI.

## Test Applications

### Single Stream Single Sink Application List:
Stateful
Stateful -> Stateless
Stateful -> Stateless -> Stateful
Stateless
Stateless -> Stateful
Stateless -> Stateful -> Stateless

#### Uncoalesced
Stateful -> Stateless
Stateful -> Stateless -> Stateful
Stateless
Stateless -> Stateful
Stateless -> Stateful -> Stateless


#### Partitioned
State Partition
State Partition -> State Partition
State Partition -> Stateful
State Partition -> Stateless

##### Uncoalesced
State Partition -> Stateless
Stateless -> State Partition
Stateless -> State Partition -> Stateless

#### Filtering Stateless
Stateless (Filter) -> Stateful
Stateless (Filter) -> Stateless
Stateful -> Stateless (Filter)
Stateless -> Stateless (Filter)

### Failing Multi Worker Topology Layout Tests
#### Related to Issue #947

Stateful -> Stateless -> Stateful

##### Uncoalesced
Stateful -> Stateless
Stateful -> Stateless -> Stateful
Stateless -> Stateful -> Stateless


##### Partitioned
State Partition -> State Partition
State Partition -> Stateful
State Partition -> Stateless

###### Uncoalesced
State Partition -> Stateless

#### Related to Issue #1021
##### Partitioned
###### Uncoalesced
Stateless -> State Partition -> Stateless
