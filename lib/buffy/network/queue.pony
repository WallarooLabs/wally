class Queue[A]
  let _data: Array[A]

  new create(data: Array[A] = Array[A]) =>
    _data = data

  fun apply(idx: USize): this->A ? => _data(idx)

  fun size(): USize => _data.size()

  fun ref enqueue(a: A) => _data.push(consume a)

  fun ref dequeue(): A ? => _data.shift()

  fun ref clear(): Array[A]^ => _data.clear()

  fun contains(a: A!, pred: {(box->A!, box->A!): Bool} val =
    lambda(l: box->A!, r: box->A!): Bool => l is r end): Bool =>
    _data.contains(a, pred)

  fun keys(): ArrayKeys[A, this->Array[A]]^ =>
    ArrayKeys[A, this->Array[A]](_data)

  fun values(): ArrayValues[A, this->Array[A]]^ =>
    ArrayValues[A, this->Array[A]](_data)

  fun pairs(): ArrayPairs[A, this->Array[A]]^ =>
    ArrayPairs[A, this->Array[A]](_data)
