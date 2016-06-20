use "collections"
use "debug"
use "assert"

class Queue[A: Any #alias]
  let _data: Array[A]
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

  new from(els: Array[A] = Array[A], len: USize = 0) =>
    """
    Create a queue of elements from the supplied array.
    """
    let n = 
      if len >= els.size() then
        len.max(2).next_pow2()
      else
        els.size().max(2).next_pow2()
      end
    _mod = n - 1
    _data = els
    _data.reserve(n)
    _size = _data.size()
    _back_ptr = _size

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
      _data((i + _front_ptr) and _mod)
    else
      error
    end

  fun ref _update(i: USize, value: A): A^ ? =>
    """
    Change the i-th element, raising an error if the index is out of bounds.
    """
    _data(i) = consume value

  fun ref enqueue(a: A) ? =>
    """
    Add an element to the back of the queue, doubling the allocation
    if the queue size has reached the allocated size and shifting any
    wrapping elements to the end of a contiguous series.
    """
    if _size < (_mod / 2) then
      if (_data.size() == 0) then
        _data.push(consume a)
        _back_ptr = _data.size() and _mod
      elseif _back_ptr >= space() then
        _back_ptr = 0
        _data(0) = consume a
      elseif _back_ptr >= _data.size() then
        _data.push(consume a)
        _back_ptr = (_back_ptr + 1) and _mod
      else
        _data(_back_ptr) = consume a
        _back_ptr = (_back_ptr + 1) and _mod
      end
    else
      let new_space = space() * 2
      _data.reserve(new_space)
      _mod = new_space - 1

      if _back_ptr >= _data.size() then
        _data.push(consume a)
        _back_ptr = _data.size() 
      elseif _front_ptr > _back_ptr then
        for i in Range(0, _back_ptr) do
          _data.push(_data(i))
        end
        _data.push(consume a)
        _back_ptr = _data.size() 
      else
        _data(_back_ptr) = consume a
        _back_ptr = (_back_ptr + 1) 
      end
    end
    _size = _size + 1
    // Assert(_data.size() <= space(), "Data size is not <= space()")
    // Assert(_size <= space(), "Size is not <= space()")
    // Assert(_size <= _data.size(), "Size is not <= data size")

  fun ref dequeue(): A! ? =>
    if _size > 0 then
      let a = _data(_front_ptr)
      _front_ptr = (_front_ptr + 1) and _mod
      _size = _size - 1
      a
    else
      error
    end

  fun peek(): this->A ? =>
    if _size > 0 then
      _data(_front_ptr)
    else
      error
    end

  fun ref clear(): Queue[A]^ =>
    """
    Remove all elements from the queue.
    The queue is returned to allow call chaining.
    """
    _size = 0
    this

  fun contains(a: A!, pred: {(box->A!, box->A!): Bool} val =
    lambda(l: box->A!, r: box->A!): Bool => l is r end): Bool =>
    """
    Returns true if the queue contains `value`, false otherwise.
    """
    try
      if _front_ptr < _back_ptr then
        for i in Range(_front_ptr, _back_ptr) do
          if pred(_data(i), a) then return true end
        end
        return false
      else
        for i in Range(_front_ptr, _data.size()) do
          if pred(_data(i), a) then return true end
        end
        for i in Range(0, _back_ptr) do
          if pred(_data(i), a) then return true end
        end
        return false
      end
    else
      false
    end

  fun values(): QueueValues[A, this->Array[A]]^ =>
    QueueValues[A, this->Array[A]](_data, _front_ptr, _back_ptr)

  fun pairs(): QueuePairs[A, this->Array[A]]^ =>
    QueuePairs[A, this->Array[A]](_data, _front_ptr, _back_ptr)

class QueueValues[A, B: Array[A] #read] is Iterator[B->A]
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
    _data(_front = (_front + 1) % _data.size())

  fun ref rewind(): QueueValues[A, B] =>
    _front = _initial_front
    _last_front = _front
    this
    
class QueuePairs[A, B: Array[A] #read] is Iterator[(USize, B->A)]
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
    (relative_idx, _data(_front = (_front + 1) % _data.size()))
        