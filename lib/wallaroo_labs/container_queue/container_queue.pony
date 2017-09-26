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

interface _Container[Data]
  fun ref write(d: Data!)
  fun ref read(): Data!

class ContainerQueue[Data, A: _Container[Data] ref]
  let _data: Array[A]
  let _container_builder: {(Data!): A}
  var _front_ptr: USize = 0
  var _back_ptr: USize = 0
  var _mod: USize = 0
  var _size: USize = 0

  new create(container_builder: {(Data!): A}, len: USize = 0) =>
    """
    Create a queue.
    """
    _container_builder = container_builder
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

  fun ref apply(i: USize): Data! ? =>
    """
    Get the i-th element from the front of the queue,
    raising an error if the index is out of bounds.
    """
    if i < _size then
      _data((i + _front_ptr) and _mod)?.read()
    else
      error
    end

  fun ref _update(i: USize, d: Data!) ? =>
    """
    Change the i-th element, raising an error if the index is out of bounds.
    """
    _data(i)?.write(d)

  fun ref enqueue(d: Data!) ? =>
    """
    Add an element to the back of the queue, doubling the allocation
    if the queue size has reached the allocated size and shifting any
    wrapping elements to the end of a contiguous series.
    """
    if _size < (_mod / 2) then
      if _data.size() == 0 then
        _data.push(_container_builder(d))
        _back_ptr = _data.size()
      elseif _back_ptr >= space() then
        _back_ptr = 0
        _data(0)?.write(d)
      elseif _back_ptr >= _data.size() then
        _data.push(_container_builder(d))
        _back_ptr = (_back_ptr + 1) and _mod
      else
        _data(_back_ptr)?.write(d)
        _back_ptr = (_back_ptr + 1) and _mod
      end
    else
      let new_space = space() * 2
      _data.reserve(new_space)
      _mod = new_space - 1

      if _back_ptr == _data.size() then
        _data.push(_container_builder(d))
        _back_ptr = _data.size()
      elseif _front_ptr > _back_ptr then
        for i in Range(0, _back_ptr) do
          _data.push(_data(i)?)
        end
        _data.push(_container_builder(d))
        _back_ptr = _data.size() and _mod
      else
        _data(_back_ptr)?.write(d)
        _back_ptr = _back_ptr + 1
      end
    end
    _size = _size + 1

  fun ref dequeue(): Data! ? =>
    if _size > 0 then
      let a = _data(_front_ptr)?
      _front_ptr = (_front_ptr + 1) and _mod
      _size = _size - 1
      a.read()
    else
      error
    end

  fun ref peek(): Data! ? =>
    if _size > 0 then
      _data(_front_ptr)?.read()
    else
      error
    end

  fun ref clear(): ContainerQueue[Data, A]^ =>
    """
    Remove all elements from the queue.
    The queue is returned to allow call chaining.
    """
    _size = 0
    _front_ptr = 0
    _back_ptr = 0
    // _data.clear()
    this

  fun ref clear_n(n: USize) =>
    if (_size > 0) and (n > 0) then
      let to_clear = if _size < (n - 1) then (_size - 1) else n end
      _front_ptr = (_front_ptr + to_clear) and _mod
      _size = _size - to_clear
    end
