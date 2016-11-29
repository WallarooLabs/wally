"""
# Invariant package

Wallaroo specific variation on the standard Pony `Assert` functionality.
Wraps our usual assertion logic into a new clean primitive.

For most invariant, you want to use the `Invariant` primitive. It handles
standard invariants such as:

```pony
Invariant(this_value > that_value)
Invariant(map.contains(key))
```

Some invariants those are more complicated. Let's take the case of the
a map where we need to look up a value and then determine if that value
is above a certain number. Because `map(key) > other_value` can throw
an error if `key` isn't in `map`, we can't use `Invariant` without
wrapping it in a `try .. else .. end` block. When you have such a
scenario, reach for `LazyInvariant`.

Rather than taking a `Bool` value for testing, `LazyInvariant` takes
a lambda expression returns a `Bool`. If the expression fails or if it
throws an error, `LazyInvariant` will fail.

```pony
LazyInvariant({()(map, key, other_value): Bool ? =>
  map(key) >= other_value})
```
"""

primitive Invariant is _InvariantFailure
  """
  This is a debug only assertion. If the test is false, it will print
  'Invariant violated' along with the source file location of the
  invariant to stderr and then forcibly exit the program.
  """
  fun apply(test: Bool, loc: SourceLoc = __loc) =>
    ifdef debug then
      if not test then
        fail(loc)
      end
    end

primitive LazyInvariant is _InvariantFailure
  """
  This is a debug only assertion. If the test is false or throws an error,
  it will print 'Invariant violated' along with the source file location
  of the invariant to stderr and then forcibly exit the program.
  """
  fun apply(f: {(): Bool ?}, loc: SourceLoc = __loc) =>
    ifdef debug then
      try
        if not f() then
          fail(loc)
        end
      else
        fail(loc)
      end
    end

trait _InvariantFailure
  """
  Common failure handling scheme for invariants.
  """
  fun fail(loc: SourceLoc) =>
    @fprintf[I32](
      @pony_os_stderr[Pointer[U8]](),
      "Invariant violated in %s at line %s\n".cstring(),
      loc.file().cstring(),
      loc.line().string().cstring())
    @exit[None](U8(1))
