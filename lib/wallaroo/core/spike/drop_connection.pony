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

class DropConnection is WallarooOutgoingNetworkActorNotify
  let _letter: WallarooOutgoingNetworkActorNotify
  let _rand: Random
  let _prob: F64
  let _margin: USize
  var _count_since_last_dropped: USize = 0
  let _c: Map[String, USize] = Map[String, USize](4)

  new iso create(config: SpikeConfig,
    letter: WallarooOutgoingNetworkActorNotify iso)
  =>
    _rand = MT(config.seed)
    _prob = config.prob
    _margin = config.margin
    _letter = consume letter

  fun ref connecting(conn: WallarooOutgoingNetworkActor ref, count: U32) =>
    ifdef "spiketrace" then
      try
        _c.upsert("connecting", 1, {(x: USize=0, y: USize): USize => x+y})?
      end
    end
    spike(conn)
    _letter.connecting(conn, count)

  fun ref connected(conn: WallarooOutgoingNetworkActor ref) =>
    ifdef "spiketrace" then
      try
        _c.upsert("connected", 1, {(x: USize=0, y: USize): USize => x+y})?
      end
    end
    spike(conn)
    _letter.connected(conn)

  fun ref connect_failed(conn: WallarooOutgoingNetworkActor ref) =>
    _letter.connect_failed(conn)

  fun ref closed(conn: WallarooOutgoingNetworkActor ref) =>
    _letter.closed(conn)

  fun ref sentv(conn: WallarooOutgoingNetworkActor ref,
    data: ByteSeqIter): ByteSeqIter
  =>
    ifdef "spiketrace" then
      try
        _c.upsert("sentv", 1, {(x: USize=0, y: USize): USize => x+y})?
      end
    end
    spike(conn)
    _letter.sentv(conn, data)

  fun ref received(conn: WallarooOutgoingNetworkActor ref, data: Array[U8] iso,
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
    // and _letter is still expecting it.
    _letter.received(conn, consume data, n)
    true

  fun ref expect(conn: WallarooOutgoingNetworkActor ref, qty: USize): USize =>
    _letter.expect(conn, qty)

   fun ref throttled(conn: WallarooOutgoingNetworkActor ref) =>
    _letter.throttled(conn)

  fun ref unthrottled(conn: WallarooOutgoingNetworkActor ref) =>
    _letter.unthrottled(conn)

  fun ref spike(conn: WallarooOutgoingNetworkActor ref) =>
    _count_since_last_dropped = _count_since_last_dropped + 1
    if _rand.real() <= _prob then
      if _margin == 0 then
        drop(conn)
      elseif _count_since_last_dropped >= _margin then
        drop(conn)
      end
    end

  fun ref drop(conn: WallarooOutgoingNetworkActor ref) =>
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
