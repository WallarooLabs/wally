// A very simple stack implementation that exists to make local topology
// initialization in Wallaroo simpler 
class Stack[V: Any #alias]
  var _size: USize = 0
  let _array: Array[V] = Array[V]

  fun ref push(v: V) =>
    try
      _array(_size) = v
    else
      _array.push(v)
    end
    _size = _size + 1

  fun ref pop(): V ? =>
    if _size > 0 then
      let popped = _array(_size - 1)
      _size = _size - 1
      popped
    else
      error
    end

  fun size(): USize => _size
