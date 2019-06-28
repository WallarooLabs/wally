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
use "debug"
use "assert"

class Queue[A: Any #alias]
  """
  A queue with expanding size for it's elements.
  
  The queue is backed by an array for its elements and expands
  the size by doubling the allocation when the queue size
  reaches the allocated size.

  An error is raised when
  * `apply` or `_update` is called with an index that is out of bounds
  * `dequeue` or `peek` is called when the queue is empty
  """
  embed _data: Array[A]
  var _front_ptr: USize = 0
  var _back_ptr: USize = 0
  var _mod: USize = 0
  var _size: USize = 0

  new create(len: USize = 0) =>
    """
    Create a queue.
    """
    let n = len.max(2).next_pow2()
    _mod = n - 1
    _data = Array[A](n)
    _size = 0

  fun size(): USize =>
    """
    The size of the queue.
    """
    _size

  fun space(): USize => _mod + 1

  fun apply(i: USize): this->A ? =>
    """
    Get the i-th element from the front of the queue,
    raising an error if the index is out of bounds.
    """
    if i < _size then
      _data((i + _front_ptr) and _mod)?
    else
      error
    end

  fun ref _update(i: USize, value: A): A^ ? =>
    """
    Change the i-th element, raising an error if the index is out of bounds.
    """
    _data(i)? = consume value

  fun ref enqueue(a: A) ? =>
    """
    Add an element to the back of the queue, doubling the allocation
    if the queue size has reached the allocated size and shifting any
    wrapping elements to the end of a contiguous series.
    """
    if _size < (_mod / 2) then
      if _data.size() == 0 then
        _data.push(consume a)
        _back_ptr = _data.size()
      elseif _back_ptr >= space() then
        _back_ptr = 0
        _data(0)? = consume a
      elseif _back_ptr >= _data.size() then
        _data.push(consume a)
        _back_ptr = (_back_ptr + 1) and _mod
      else
        _data(_back_ptr)? = consume a
        _back_ptr = (_back_ptr + 1) and _mod
      end
    else
      let new_space = space() * 2
      _data.reserve(new_space)
      _mod = new_space - 1

      if _back_ptr == _data.size() then
        _data.push(consume a)
        _back_ptr = _data.size()
      elseif _front_ptr > _back_ptr then
        for i in Range(0, _back_ptr) do
          _data.push(_data(i)?)
        end
        _data.push(consume a)
        _back_ptr = _data.size() and _mod
      else
        _data(_back_ptr)? = consume a
        _back_ptr = _back_ptr + 1
      end
    end
    _size = _size + 1

  fun ref dequeue(): A! ? =>
    if _size > 0 then
      let a = _data(_front_ptr)?
      _front_ptr = (_front_ptr + 1) and _mod
      _size = _size - 1
      a
    else
      error
    end

  fun peek(): this->A ? =>
    """
    Return the first element from the front of the queue
    raising an error if the queue is empty.
    """
    if _size > 0 then
      _data(_front_ptr)?
    else
      error
    end

  fun ref clear(): Queue[A]^ =>
    """
    Remove all elements from the queue.
    The queue is returned to allow call chaining.
    """
    _size = 0
    _front_ptr = 0
    _back_ptr = 0
    this

  fun ref clear_n(n: USize) =>
    """
    Clear the first `n` elements or all the elements from
    the queue if n is greater than the current queue size.
    """
    if (_size > 0) and (n > 0) then
      let to_clear = if _size < (n - 1) then (_size - 1) else n end
      _front_ptr = (_front_ptr + to_clear) and _mod
      _size = _size - to_clear
    end

  fun contains(a: A!, pred: {(box->A!, box->A!): Bool} val =
    {(l: box->A!, r: box->A!): Bool => l is r}): Bool =>
    """
    Returns true if the queue contains `value`, false otherwise.
    """
    try
      if _front_ptr < _back_ptr then
        for i in Range(_front_ptr, _back_ptr) do
          if pred(_data(i)?, a) then return true end
        end
        return false
      else
        for i in Range(_front_ptr, _data.size()) do
          if pred(_data(i)?, a) then return true end
        end
        for i in Range(0, _back_ptr) do
          if pred(_data(i)?, a) then return true end
        end
        return false
      end
    else
      false
    end

  fun values(): QueueValues[A, this->Array[A]]^ =>
	"""
	Return a `QueueValues` iterator.
	"""
    QueueValues[A, this->Array[A]](_data, _front_ptr, _back_ptr)

  fun pairs(): QueuePairs[A, this->Array[A]]^ =>
    """
    Return a `QueuePairs` iterator.
    """
    QueuePairs[A, this->Array[A]](_data, _front_ptr, _back_ptr)

class QueueValues[A, B: Array[A] #read] is Iterator[B->A]
  """
  An `Iterator` over the elements in the queue.
  """
  let _data: B
  var _front: USize
  var _last_front: USize
  let _back: USize
  let _initial_front: USize

  new create(data: B, front: USize, back: USize) =>
    _data = data
    _front = front
    _last_front = _front
    _back = back
    _initial_front = front

  fun has_next(): Bool =>
    if _front >= _last_front then
      _front != _back
    else
      (_back < _data.size()) and (_front != _back)
    end

  fun ref next(): B->A ? =>
    _last_front = _front
    _data(_front = (_front + 1) % _data.size())?

  fun ref rewind(): QueueValues[A, B] =>
    _front = _initial_front
    _last_front = _front
    this

class QueuePairs[A, B: Array[A] #read] is Iterator[(USize, B->A)]
  """
  An `Iterator` of tuples `(USize, B->A)` with elements in the queue
  and their corresponding relative indexes from the front of the queue.
  """
  let _data: B
  var _front: USize
  var _last_front: USize
  let _back: USize
  let _initial_front: USize

  new create(data: B, front: USize, back: USize) =>
    _data = data
    _front = front
    _last_front = _front
    _back = back
    _initial_front = _front

  fun has_next(): Bool =>
    if _front >= _last_front then
      _front != _back
    else
      (_back < _data.size()) and (_front != _back)
    end

  fun ref next(): (USize, B->A) ? =>
    _last_front = _front
    let relative_idx =
      if _front >= _initial_front then
        _front - _initial_front
      else
        _front + (_data.size() - _initial_front)
      end
    (relative_idx, _data(_front = (_front + 1) % _data.size())?)

