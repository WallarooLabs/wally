use "collections"
use "serialise"
use "sendence/bytes"

class ByteBuffer
  let _data: Array[U8]
  let _threshold: USize
  var _size: USize = 0

  new create(len: USize) =>
    // HACK: Add some extra headroom to the array so we have space for the
    // last serialised data structure
    _data = Array[U8](len + 1000)
    _threshold = len
    for i in Range(0, len) do
      _data.push(0)
    end

  fun apply(idx: USize): U8 ? =>
    if idx >= _size then error end

    _data(idx)

  fun ref add_serialised[M: Any val](msg: M, auth: AmbientAuth): USize ? =>
    let serialised_buffer = SerialisedBuffer(SerialiseAuth(auth), msg, _data,
      _size + 4)
    Bytes.write_u32_at_idx(serialised_buffer.size().u32(), _data, _size)
    _size = _size + 4 + serialised_buffer.size()
    4 + serialised_buffer.size()

  fun ref push(byte: U8) ? =>
    if _size == _data.size() then
      _data.push(byte)
    else
      _data(_size) = byte
    end
    _size = _size + 1

  fun ref clear() =>
    _size = 0

  fun is_full(): Bool => _size > _threshold

  fun size(): USize => _size

  fun ref values(): ByteBufferValues^ =>
    """
    Return an iterator over the values in the underlying array up to _size.
    """
    ByteBufferValues(_data, _size)

class ByteBufferValues is Iterator[U8]
  let _array: Array[U8]
  let _size: USize
  var _i: USize

  new create(array: Array[U8], size: USize) =>
    _array = array
    _size = size
    _i = 0

  fun has_next(): Bool =>
    _i < _size

  fun ref next(): U8 ? =>
    _array(_i = _i + 1)

  fun ref rewind(): ByteBufferValues =>
    _i = 0
    this
