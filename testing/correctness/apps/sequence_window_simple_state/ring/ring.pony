/*

Copyright 2017 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

use "collections"

class Ring[A: Any val]
  """
  A parametrised ring buffer data structure.

  Usage:
  ```pony
  // Create a ring buffer of 4 U64 elements
  let r = Ring[U64](4)

  // Push some values into it
  for v in Range[U64](0,100) do
    r.push(v)
  end

  // Read the values, beginning with the most recent, and ending with the least
  // recent
  for i in Range[USize](0, r.size()) do
    r(i)
  end

  // We can also use values() to do the same
  for v in r.values() do
    // do something with the value..
    let x = v
  end

  // keys() and pairs() operate similarly to Array.keys() and Array.pairs()

  // raw() exposes the internal ring values, and from_array(array, size, count)
  // allows us to recreate a new ring from those values
  (let buf, let size, let count) = r.raw()
  let r' = Ring[U64].from_array(consume buf, size, count)

  // Note that trying to read an index >= size will result in an error
  try
    r(r.size())
  else
    env.err.print("Couldn't read at this index!")
  end
  ```

  The `string(delim: String, fill: String, f: {(A): String?})` method
  makes a best effort attempt to convert the ring buffer to a string.
  The defaults for `delim` and `fill` are `",'` and `""` respectively.
  If the date type used isn't `Stringable`, you will have to provide your own
  String conversion via a lambda, `f`.
  e.g.
  ```pony
  class val MyNonStringable
    let x: U64
    let y: U64

    new val create(x': U64, y': U64) =>
      x = x'
      y = y'


  // Create a ring buffer of `MyType`
  let r = Ring[MyNonStringable](4)
  for x in Range[U64](0,10) do
    r.push(MyNonStringable(x,x*2))
  end

  try
    let s = r.string()  // This will fail
  else
    // Stringify to (x,y)
    let f': {(MyNonStringable): String} val = {(a: MyNonStringable): String
      =>
        "(" + a.x.string() + "," + a.y.string() + ")"
    }
    let s = r.string(where f = f')
  end
  ```
  """

  var _buf: Array[A]
  let _size: USize
  var _count: USize = 0

  new create(len: USize = 4) =>
    """
    Create a ring with zero elements but space for len elements.
    """
    _buf = Array[A](len)
    _size = len

  new from_array(a: Array[A] iso, size': USize, count': USize) =>
    """
    Create a ring from an existing array, and the size, position, and count
    variables.
    Size must match the array size.
    """
    if size' < a.size() then
      _size = a.size()
    else
      _size = size'
    end
    _count = count'
    _buf = consume a

  fun raw(): (Array[A] iso^, USize, USize) =>
    """
    Get the underlying array, size, position, and count values of the ring.
    These values can be used with `from_array` to create an identical new Ring.
    """
    let a: Array[A] iso = recover iso Array[A](_size) end
    for v in _buf.values() do
      a.push(v)
    end
    (consume a, _size, _count)

  fun _index(i: USize): USize ? =>
    """
    Buffer index for i. 0 is the most recent, and `size()-1` is the least.
    """
    if i >= _buf.size() then error end
      ((_count-1)-i) % _size


  fun apply(i: USize): this->A? =>
    """
    Get the value at i. 0 is the most recent, and `size()-1` is the least.
    """
    _buf(_index(i)?)?

  fun size(): USize =>
    """
    The size of the ring.
    """
    _buf.size()

  fun count(): USize =>
    """
    The number of elements that have been inserted into the ring.
    May be larger than size.
    """
    _count

  fun pos(): USize =>
    """
    The current position of the producer on the ring.
    """
    _count % _size

  fun ref push(value: A): Ring[A]^ =>
    """
    Add an element to the end of the ring, overwriting the oldest existing
    element if the ring is already full.
    The ring is returned to allow call chaining.
    """
    try
      if _buf.size() < _size then
        _buf.push(consume value)
      else
        _buf.update(_count % _size, consume value)?
      end
      _count = _count + 1
    end
    this

  fun keys(): RingKeys[A, this->Ring[A]]^ =>
    """
    Return an iterator over the indices in the ring.
    """
    RingKeys[A, this->Ring[A]](this)

  fun values(): RingValues[A, this->Ring[A]]^ =>
    """
    Return an iterator over the values in the ring.
    """
    RingValues[A, this->Ring[A]](this)

  fun pairs(): RingPairs[A, this->Ring[A]]^ =>
    """
    Return an iterator over the (index, value) pairs in the ring.
    """
    RingPairs[A, this->Ring[A]](this)

  fun string(delim: String = ",", fill: String = "",
    f: {(A): String ?} val = {(a: A): String ? => (a as Stringable).string()}):
    String ?
  =>
    """
    Return a string representation of the ring.
    `delim` and `fill` default to `","` and `""` respecitvely.
    If the objects in the ring are not `Stringable`, use the lambda parameter
    `f` to provide your own method for converting the objects to strings.
    """
    let a: Array[String] = recover Array[String] end
    for v in values() do
      match v
      | let s': Stringable =>
        a.push(s'.string())
      else
        a.push(f(v)?)
      end
    end
    for x in Range[USize](0, _size - _buf.size()) do
      a.push(fill)
    end
    let s: String iso = recover iso String end
    s.append("[")
    s.append(delim.join((consume a).reverse().values()))
    s.append("]")
    s

class RingKeys[A: Any val, B: Ring[A] #read] is Iterator[USize]
  let _ring: B
  var _i: USize

  new create(ring: B) =>
    _ring = ring
    _i = 0

  fun has_next(): Bool =>
    _i < _ring.size()

  fun ref next(): USize =>
    if _i < _ring.size() then
      _i = _i + 1
    else
      _i
    end

class RingValues[A: Any val, B: Ring[A] #read] is Iterator[B->A]
  let _ring: B
  var _i: USize

  new create(ring: B) =>
    _ring = ring
    _i = 0

  fun has_next(): Bool =>
    _i < _ring.size()

  fun ref next(): B->A ? =>
    _ring(_i = _i + 1)?

  fun ref rewind(): RingValues[A, B] =>
    _i = 0
    this

class RingPairs[A: Any val, B: Ring[A] #read] is Iterator[(USize, B->A)]
  let _ring: B
  var _i: USize

  new create(ring: B) =>
    _ring = ring
    _i = 0

  fun has_next(): Bool =>
    _i < _ring.size()

  fun ref next(): (USize, B->A) ? =>
    (_i, _ring(_i = _i + 1)?)
