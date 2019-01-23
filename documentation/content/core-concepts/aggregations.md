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

Let's look at the example of a user-defined `MySumAgg` aggregation, using the Python API (the API-specific details are explained [here](/python-tutorial/api); we're taking a higher level view at the moment). We first define a helper class `_MySum` which is used as our accumulator:

```python
class _MySum():
    def __init__(self, initial_total):
        self.total = initial_total

    def add(self, value):
        self.total = self.total + value

class MySumAgg(wallaroo.Aggregation):
    def initial_accumulator(self):
        return _MySum(0)

    def update(self, input, sum):
        sum.add(input.value)

    def combine(self, sum1, sum2):
        return _MySum(sum1.total + sum2.total)

    def output(self, key, sum):
        return MyOutputType(key, sum.total)
```

## Required Properties

There are four properties the implementation of an aggregation must satisfy or else your application results may be incorrect. These are:

1) The `combine` method must be associative. This means:
```python
# ((s1 . s2) . s3) = (s1 . (s2 . s3))
# in code:
a.combine(a.combine(s1, s2), s3) == a.combine(s1, a.combine(s2, s3))
```
Our `MySumAgg` aggregation satisfies this because addition is associative.

2) The `combine` method must not mutate either of its arguments. This means: either you must create a new accumulator to return or you must return one of 
the argument accumulators without mutating it.

Our `MySumAgg` aggregation satisfies this because we treat the `sum1` and `sum2` arguments as read-only and create a new `_MySum` by adding their totals.

3) The `initial_accumulator` must act as an identity element for the `combine` function. This means:
```python
# (i . s) = s
# in code:
a.combine(a.initial_accumulator(), s) == s
```
and
```python
# (s . i) = s
# in code:
a.combine(s, a.initial_accumulator()) == s
```
Our `MySumAgg` aggregation satisfies this because 0 is the identity element for addition and our initial accumulator is `_MySum(0)`.

4) The `output` method must not mutate its accumulator argument.

Our `MySumAgg` aggregation satisfies this because we only read the `total` attribute from the `sum` argument.
