"""
Sequence Window is an application designed to test recovery

It holds the last 4 values observed in an ordered ring buffer, and on every
incoming new value, it replaces the oldest value with the new value, and prints
the last 4 values (including the current one.

The ring buffer holding the last 4 values represents Stateful memory that should
be recovered. The input is a binary encoded sequence of U64 integers,
and the output is the encoded string of the array, in the format
"[a, b, c, d]\n"

To run, use the following commands:
1. Giles receiver:
```
../../giles/receiver/receiver --ponythreads=1 --ponynoblock --ponypinasio -l 127.0.0.1:5555
```
2. Initializer worker
```
./sequence-window -i 127.0.0.1:7000 -o 127.0.0.1:5555 -m 127.0.0.1:5001 --ponythreads=4 --ponypinasio --ponynoblock -c 127.0.0.1:12500 -d 127.0.0.1:12501 -r res-data -w 2 -n worker1 -t
```
3. Second worker
```
./sequence-window -i 127.0.0.1:7000 -o 127.0.0.1:5555 -m 127.0.0.1:5001 --ponythreads=4 --ponypinasio --ponynoblock -c 127.0.0.1:12500 -d 127.0.0.1:12501 -r res-data -w 2 -n worker2
```
4. Sender
```
../../giles/sender/sender -b 127.0.0.1:7000 -s 1 -i 1_000_000_000 -u --ponythreads=1 -y -g 12 -w -m 1000
```
"""

use "debug"
use "buffered"
use "collections"
use "sendence/bytes"
use "wallaroo/"
use "wallaroo/tcp-source"
use "wallaroo/topology"

actor Main
  new create(env: Env) =>
    try
      let part_ar: Array[(U64, USize)] val = recover 
        let pa = Array[(U64, USize)]
        pa.push((0,0))
        consume pa
      end
      let partition = Partition[U64, U64](WindowPartitionFunction, part_ar)

      let application = recover val
        Application("Sequence Window Printer")
          .new_pipeline[U64 val, String val]("Sequence Window",
            U64FramedHandler)
            .to_state_partition[U64 val, U64 val, String val,
              WindowState](ObserveNewValue, WindowStateBuilder, "window-state",
                partition where multi_worker = true)
            .to_sink(WindowEncoder, recover [0] end)
      end
      Startup(env, application, "sequence-window")
    else
      env.out.print("Couldn't build topology")
    end


primitive WindowPartitionFunction
  fun apply(u: U64 val): U64 =>
    // Always use the same partition
    0


class val WindowStateBuilder
  fun apply(): WindowState => WindowState
  fun name(): String => "Window State"


class WindowState
  var idx: USize = 0
  var ring: Ring = Ring(4)

  fun string(): String =>
    ring.string()

  fun ref push(u: U64): U64 =>
    let o = ring.push(u)
    idx = idx + 1
    o


class WindowStateChange is StateChange[WindowState]
  // Log size is 4x U64 + 2x USize (U64?)
  var _id: U64
  var _window: WindowState = WindowState

  new create(id': U64) =>
    _id = id'

  fun name(): String => "UpdateWindow"
  fun id(): U64 => _id

  fun ref update(u: U64 val) =>
    _window.push(u)

  fun string(): String =>
    _window.string()

  fun apply(state: WindowState ref) =>
    for v in _window.ring.values() do
      state.push(v)
    end
    state.idx = _window.idx

  fun write_log_entry(out_writer: Writer) =>
    // 1xUSize->idx | 4xU64->Ring | 1xUSize->Ring.Pos
    out_writer.u64_be(_window.idx.u64())
    for v in _window.ring.values() do
      out_writer.u64_be(v)
    end
    out_writer.u64_be(_window.ring.pos().u64())

  fun ref read_log_entry(in_reader: Reader) ? =>
    let idx' = in_reader.u64_be().usize()
    let a = recover Array[U64 val] end
    for x in Range[USize](0,4) do
      a.push(in_reader.u64_be())
    end
    let a': Array[U64 val] val = consume a
    let pos' = in_reader.u64_be().usize()
    _window = WindowState
    _window.idx = idx'
    _window.ring.update(a', pos')


class WindowStateChangeBuilder is StateChangeBuilder[WindowState]
  fun apply(id: U64): StateChange[WindowState] =>
    WindowStateChange(id)

primitive ObserveNewValue is StateComputation[U64 val, String val, WindowState]
  fun name(): String => "Observe new value"

  fun apply(u: U64 val,
    sc_repo: StateChangeRepository[WindowState],
    state: WindowState): (String val, StateChange[WindowState] ref)
  =>
    let state_change: WindowStateChange ref =
      try
        sc_repo.lookup_by_name("UpdateWindow") as WindowStateChange
      else
        WindowStateChange(0)
      end

    state_change.update(u)

    // TODO: This is ugly since this is where we need to simulate the state
    // change in order to produce a result
    (state_change.string(), state_change)

  fun state_change_builders():
    Array[StateChangeBuilder[WindowState] val] val
  =>
    recover val
      let scbs = Array[StateChangeBuilder[WindowState] val]
      scbs.push(recover val WindowStateChangeBuilder end)
    end


primitive U64FramedHandler is FramedSourceHandler[U64 val]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

  fun decode(data: Array[U8] val): U64 ? =>
    Bytes.to_u64(data(0), data(1), data(2), data(3),
      data(4), data(5), data(6), data(7))


primitive WindowEncoder
  fun apply(s: String val, wb: Writer = Writer): Array[ByteSeq] val =>
    wb.write(s)
    wb.done()


class Ring
  var _buf: Array[U64 val]
  var _pos: USize = 0
  let _size: USize

  new create(len: USize = 4) =>
    _buf = Array[U64 val](4).init(0, len)
    _size = len

  fun size(): USize =>
    _size

  fun pos(): USize =>
    _pos

  fun ref push(u: U64): U64 =>
    // Replace value in pos % size with u. Return old value.
    let o: U64 = try
      _buf(_pos % _size)
    else
      0
    end
    try
      _buf.update(_pos % _size, u)
    end
    _pos = _pos + 1
    consume o

  fun ref update(a: Array[U64 val] val, pos': USize) ? =>
    if a.size() != _buf.size() then error end
    _pos = pos'
    for (idx,v) in a.pairs() do
      _buf.update(idx, v)
    end

  fun val apply(i: USize): U64 val ? =>
    _buf(i)

  fun values(): ArrayValues[U64, Array[U64]] =>
    let a = Array[U64]
    a.push(try _buf((_pos+0) % _size) else 0 end)
    a.push(try _buf((_pos+1) % _size) else 0 end)
    a.push(try _buf((_pos+2) % _size) else 0 end)
    a.push(try _buf((_pos+3) % _size) else 0 end)
    a.values()

  fun string(): String =>
    let u0: String val = try _buf(_pos % _size).string() else "x" end
    let u1: String val = try _buf((_pos+1) % _size).string() else "x" end
    let u2: String val = try _buf((_pos+2) % _size).string() else "x" end
    let u3: String val = try _buf((_pos+3) % _size).string() else "x" end
    let o' = recover
      let o = String
      o.append("[")
      o.append(u0)
      o.append(", ")
      o.append(u1)
      o.append(", ")
      o.append(u2)
      o.append(", ")
      o.append(u3)
      o.append("]")
      consume o
    end
    o'
