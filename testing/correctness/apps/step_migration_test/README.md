Step Migration Test App
=======================

THIS IS NOT A FULL WALLAROO APP.

It creates two "counter" steps and sends messages to one, transfers state, then
sends messages to the other. It is used to validate state transfer between steps
of the same type. If you run it, expect output similar to what is transcribed
below. The warnings about sending messages to an EmptyRouter are expected.

```
steps created
1
route_with_target_id() was called on an EmptyOmniRouter
2
route_with_target_id() was called on an EmptyOmniRouter
3
route_with_target_id() was called on an EmptyOmniRouter
4
route_with_target_id() was called on an EmptyOmniRouter
5
route_with_target_id() was called on an EmptyOmniRouter
6
route_with_target_id() was called on an EmptyOmniRouter
7
route_with_target_id() was called on an EmptyOmniRouter
8
route_with_target_id() was called on an EmptyOmniRouter
9
route_with_target_id() was called on an EmptyOmniRouter
10
route_with_target_id() was called on an EmptyOmniRouter
1
route_with_target_id() was called on an EmptyOmniRouter
2
route_with_target_id() was called on an EmptyOmniRouter
3
route_with_target_id() was called on an EmptyOmniRouter
4
route_with_target_id() was called on an EmptyOmniRouter
5
route_with_target_id() was called on an EmptyOmniRouter
6
route_with_target_id() was called on an EmptyOmniRouter
7
route_with_target_id() was called on an EmptyOmniRouter
8
route_with_target_id() was called on an EmptyOmniRouter
9
route_with_target_id() was called on an EmptyOmniRouter
10
route_with_target_id() was called on an EmptyOmniRouter
Received new state
metrics outgoing connected
metrics outgoing connected
metrics outgoing connected
```
