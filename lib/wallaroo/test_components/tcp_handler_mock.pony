/*

Copyright 2019 The Wallaroo Authors.

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

use "net"
use "wallaroo/core/tcp_actor"


class val MockTCPHandlerBuilder is TestableTCPHandlerBuilder
  let _rw_builder: TestReaderWriterBuilder
  new val create(rw_builder: TestReaderWriterBuilder) =>
    _rw_builder = rw_builder

  fun apply(tcp_actor: TCPActor ref): TestableTCPHandler =>
    MockTCPHandler(tcp_actor, _rw_builder)

class MockTCPHandler is TestableTCPHandler
  let _tcp_actor: TCPActor ref
  // let _lfq: TestLockFreeQueue
  let _reader_writer: TestReaderWriter

  // new create(tcp_actor: TCPActor ref, lfq: TestLockFreeQueue) =>
  new create(tcp_actor: TCPActor ref, rw_builder: TestReaderWriterBuilder) =>
    _tcp_actor = tcp_actor
    _reader_writer = rw_builder()
    // _lfq = lfq
    // Start the TCPActor reading
    tcp_actor.read_again()

  fun is_connected(): Bool =>
    true

  fun ref accept() =>
    None

  fun ref connect(host: String, service: String) =>
    None

  fun ref event_notify(event: AsioEventID, flags: U32, arg: U32) =>
    None

  fun ref write(data: ByteSeq) =>
    _reader_writer.write(data)
    // _lfq.enqueue(data)

  fun ref writev(data: ByteSeqIter) =>
    for bs in data.values() do
      write(bs)
    end

  fun ref close() =>
    None

  fun can_send(): Bool =>
    true

  fun ref read_again() =>
    match _reader_writer.try_read()
    | let arr: Array[U8] iso =>
      _tcp_actor.received(consume arr, 1)
    // if not _lfq.is_empty() then
    //   let next = _lfq.dequeue()
    //   // Do something with next
    // end
    end
    _tcp_actor.read_again()

  fun ref write_again() =>
    None

  fun ref expect(qty: USize) =>
    _reader_writer.expect(qty)

  fun ref set_nodelay(state: Bool) =>
    None

  fun local_address(): NetAddress =>
    NetAddress

  fun remote_address(): NetAddress =>
    NetAddress

  fun ref mute() =>
    None

  fun ref unmute() =>
    None
