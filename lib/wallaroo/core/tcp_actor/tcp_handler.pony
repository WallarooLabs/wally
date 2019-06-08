/*

Copyright (C) 2016-2017, Wallaroo Labs
Copyright (C) 2016-2017, The Pony Developers
Copyright (c) 2014-2015, Causality Ltd.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

use "buffered"
use "collections"
use "net"
use "wallaroo_labs/bytes"
use "wallaroo_labs/mort"


interface val TestableTCPHandlerBuilder
  fun apply(tcp_actor: TCPActor ref): TestableTCPHandler

  fun for_connection(fd: U32, init_size: USize = 64, max_size: USize = 16384,
    tcp_actor: TCPActor ref, muted: Bool): TestableTCPHandler
  =>
    //!@ Temporary fix because of Pony wallaroo_labs/mort import bug
    tcp_actor.fail()
    apply(tcp_actor)

trait TestableTCPHandler
  fun is_connected(): Bool

  fun ref accept()

  fun ref connect(host: String, service: String)

  fun ref event_notify(event: AsioEventID, flags: U32, arg: U32)

  fun ref write(data: ByteSeq)

  fun ref writev(data: ByteSeqIter)

  fun ref close()

  fun can_send(): Bool

  fun ref read_again()

  fun ref write_again()

  fun ref expect(qty: USize)

  fun ref set_nodelay(state: Bool)

  fun local_address(): NetAddress

  fun remote_address(): NetAddress

  /////////////
  // TODO: these mute/unmute methods should be removed
  fun ref mute() => Fail()
  fun ref unmute() => Fail()

class EmptyTCPHandler is TestableTCPHandler
  fun is_connected(): Bool => false

  fun ref accept() =>
    None

  fun ref connect(host: String, service: String) =>
    None

  fun ref event_notify(event: AsioEventID, flags: U32, arg: U32) =>
    Fail()
    None

  fun ref write(data: ByteSeq) =>
    None

  fun ref writev(data: ByteSeqIter) =>
    None

  fun ref close() =>
    None

  fun can_send(): Bool =>
    false

  fun ref read_again() =>
    None

  fun ref write_again() =>
    None

  fun ref expect(qty: USize) =>
    None

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

