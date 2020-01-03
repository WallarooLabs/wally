---
title: "Aggregations"
menu:
  toc:
    parent: "core-concepts"
    weight: 5
toc: true
---
Aggregations are an alternative to state computations that trade some of the freedom provided by state computations for the ability to efficiently compute results in windows.

An aggregation consists of four parts:
1) The initial accumulator state.
2) An `update` function that takes an input and the accumulator state and optionally updates the accumulator.
3) A `combine` function that takes two accumulators and returns an accumulator that represents the combine of both of them.
4) An `output` function that takes a key and an accumulator and optionally outputs an aggregation result.

Let's look at the example of a user-defined `MySumAgg` aggregation, using the Pony API (the API-specific details are explained [here](/pony-tutorial/api); we're taking a higher level view at the moment). We first define a helper class `MySum` which is used as our accumulator and a helper class `Event`:

```
class val Event
  // A generic event, bearing a key and a piece of data.
  let event_data: U32
  let event_key: Key

  new val create(data: U32, key: Key) =>
    event_data = data
    event_key = key

class MySum is State
  var sum_of_event_data: U32

  new create(sum: U32) =>
    sum_of_event_data = sum

primitive MySumAgg is Aggregation[Event, Event, MySum]
  fun initial_accumulator(): MySum =>
    MySum(0)

  fun update(e: Event, my_sum: MySum) =>
    my_sum.sum_of_event_data =
      my_sum.sum_of_event_data + e.event_data

  fun combine(sum1: MySum box, sum2: MySum box): MySum =>
    MySum(sum1.sum_of_event_data + sum2.sum_of_event_data)

  fun output(key: Key, sum: MySum): (None | Event) =>
    if sum.sum_of_event_data > 0 then
      Event(sum.sum_of_event_data, key)
    end

  fun name(): String =>
```

## Required Properties

There are four properties the implementation of an aggregation must satisfy or else your application results may be incorrect. These are:

1) The `combine` method must be associative. This means:
```
# ((s1 . s2) . s3) = (s1 . (s2 . s3))
# in code:
a.combine(a.combine(s1, s2), s3) == a.combine(s1, a.combine(s2, s3))
```
Our `MySumAgg` aggregation satisfies this because addition is associative.

2) The `combine` method must not mutate either of its arguments. This means: either you must create a new accumulator to return or you must return one of
the argument accumulators without mutating it.

Our `MySumAgg` aggregation satisfies this because we treat the `sum1` and `sum2` arguments as read-only, signified by the box alias, and create a new `MySum` by adding their totals.

3) The `initial_accumulator` must act as an identity element for the `combine` function. This means:
```
# (i . s) = s
# in code:
a.combine(a.initial_accumulator(), s) == s
```
and
```
# (s . i) = s
# in code:
a.combine(s, a.initial_accumulator()) == s
```
Our `MySumAgg` aggregation satisfies this because 0 is the identity element for addition and our initial accumulator is `MySum(0)`.

4) The `output` method must not mutate its accumulator argument.

Our `MySumAgg` aggregation satisfies this because we only read the `sum_of_event_data` attribute from the `sum` argument.
