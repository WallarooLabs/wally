/*

Copyright 2018 The Wallaroo Authors.

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
use "random"
use "wallaroo/core/network"

class DropConnection[T: TCPActor ref] is TCPHandlerNotify[T]
  let _wrapped_notify: TCPHandlerNotify[T]
  let _rand: Random
  let _prob: F64
  let _margin: USize
  var _count_since_last_dropped: USize = 0
  let _c: Map[String, USize] = Map[String, USize](4)

  new create(config: SpikeConfig, wrapped_notify: TCPHandlerNotify[T])
  =>
    _rand = MT(config.seed)
    _prob = config.prob
    _margin = config.margin
    _wrapped_notify = wrapped_notify

  fun ref connecting(conn: T, count: U32) =>
    ifdef "spiketrace" then
      try
        _c.upsert("connecting", 1, {(x: USize=0, y: USize): USize => x+y})?
      end
    end
    spike(conn)
    _wrapped_notify.connecting(conn, count)

  fun ref connected(conn: T) =>
    ifdef "spiketrace" then
      try
        _c.upsert("connected", 1, {(x: USize=0, y: USize): USize => x+y})?
      end
    end
    spike(conn)
    _wrapped_notify.connected(conn)

  fun ref connect_failed(conn: T) =>
    _wrapped_notify.connect_failed(conn)

  fun ref closed(conn: T, locally_initiated_close: Bool) =>
    _wrapped_notify.closed(conn, locally_initiated_close)

  fun ref sentv(conn: T,
    data: ByteSeqIter): ByteSeqIter
  =>
    ifdef "spiketrace" then
      try
        _c.upsert("sentv", 1, {(x: USize=0, y: USize): USize => x+y})?
      end
    end
    spike(conn)
    _wrapped_notify.sentv(conn, data)

  fun ref received(conn: T, data: Array[U8] iso,
    n: USize): Bool
  =>
    ifdef "spiketrace" then
      try
        _c.upsert("received", 1, {(x: USize=0, y: USize): USize => x+y})?
      end
    end
    spike(conn)
    // We need to always send the data we've read from the buffer along.
    // Even when we drop the connection, we've already read that data
    // and _wrapped_notify is still expecting it.
    _wrapped_notify.received(conn, consume data, n)
    true

  fun ref expect(conn: T, qty: USize): USize =>
    _wrapped_notify.expect(conn, qty)

   fun ref throttled(conn: T) =>
    _wrapped_notify.throttled(conn)

  fun ref unthrottled(conn: T) =>
    _wrapped_notify.unthrottled(conn)

  fun ref spike(conn: T) =>
    _count_since_last_dropped = _count_since_last_dropped + 1
    if _rand.real() <= _prob then
      if _margin == 0 then
        drop(conn)
      elseif _count_since_last_dropped >= _margin then
        drop(conn)
      end
    end

  fun ref drop(conn: T) =>
    ifdef debug then
      @printf[I32]("\n((((((SPIKE: DROPPING CONNECTION!))))))\n\n".cstring())
    end
    // reset count, return true
    _count_since_last_dropped = 0
    ifdef "spiketrace" then
      // print and reset counts
      _print_counts()
      _c.clear()
    end
    // drop connection
    conn.close()

  fun _print_counts() =>
    try
      let a: Array[U8] iso = recover Array[U8] end
      a.append("SPIKE Counts: {")
      for (k, v) in _c.pairs() do
        a.append(k)
        a.append(": ")
        a.append(v.string())
        a.append(", ")
      end
      a.pop()?
      a.pop()?
      a.append("}\n")
      let s = String.from_array(consume a)
      @printf[I32](s.cstring())
    end
