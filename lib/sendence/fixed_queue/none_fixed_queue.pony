// """
// A queue with a fixed max size. Attempting to enqueue more data than this
// max size will throw an error. Essentially, this is a ring buffer with a
// queue interface.
// """

use "collections"
use "debug"
use "assert"

class NoneFixedQueue[A]
  embed _data: Array[(A | None)]
  let _max_size: USize
  var _front_ptr: USize = 0
  var _back_ptr: USize = 0
  var _mod: USize = 0
  var _size: USize = 0

  new create(len: USize) =>
    """
    Create a queue.
    """
    _max_size = len
    let n = len.max(2).next_pow2()
    _mod = n - 1
    _data = Array[(A | None)](n)
    _size = 0

  fun size(): USize =>
    """
    The size of the queue.
    """
    _size

  fun max_size(): USize =>
    """
    The max size of the queue.
    """
    _max_size

  fun space(): USize =>
    _mod + 1

  fun apply(i: USize): this->A ? =>
    """
    Get the i-th element from the front of the queue,
    raising an error if the index is out of bounds.
    """
    if i < _size then
      let a = _data((i + _front_ptr) and _mod)
      match a
      | let item: this->A => item
      else
        error
      end
    else
      error
    end

  fun ref enqueue(a: A) ? =>
    """
    Add an element to the back of the queue
    """
    if _size >= _max_size then
      error
    end

    if _data.size() < _max_size then
      _data.push(consume a)
      _back_ptr = (_back_ptr + 1) and _mod
    else
      _data(_back_ptr) = consume a
      _back_ptr = (_back_ptr + 1) and _mod
    end
    _size = _size + 1

  fun ref dequeue(): A! ? =>
    if _size > 0 then
      let a = _data(_front_ptr)
      _data(_front_ptr) = None
      _front_ptr = (_front_ptr + 1) and _mod
      _size = _size - 1
      match a
      | let item: A => item
      else
        error
      end
    else
      error
    end

  fun peek(): this->A ? =>
    if _size > 0 then
      let a = _data(_front_ptr)
      match a
      | let item: this->A => item
      else
        error
      end
    else
      error
    end

  fun ref clear(): NoneFixedQueue[A]^ =>
    """
    Remove all elements from the queue.
    The queue is returned to allow call chaining.
    """
    _size = 0
    _front_ptr = 0
    _back_ptr = 0
    for i in Range(0, _data.size()) do
      try _data(i) = None end
    end
    this

  fun ref clear_n(n: USize) =>
    if (_size > 0) and (n > 0) then
      let to_clear = if _size < (n - 1) then (_size - 1) else n end
      for i in Range(0, to_clear) do
        try _data(_front_ptr) = None end
        _front_ptr = (_front_ptr + 1) and _mod
      end
      _size = _size - to_clear
    end

  // fun contains(a: A!, pred: {(box->A!, box->A!): Bool} val =
  //   {(l: box->A!, r: box->A!): Bool => l is r}): Bool =>
  //   """
  //   Returns true if the queue contains `value`, false otherwise.
  //   """
  //   try
  //     if _front_ptr < _back_ptr then
  //       for i in Range(_front_ptr, _back_ptr) do
  //         if pred(_data(i), a) then return true end
  //       end
  //       return false
  //     else
  //       for i in Range(_front_ptr, _data.size()) do
  //         if pred(_data(i), a) then return true end
  //       end
  //       for i in Range(0, _back_ptr) do
  //         if pred(_data(i), a) then return true end
  //       end
  //       return false
  //     end
  //   else
  //     false
  //   end

