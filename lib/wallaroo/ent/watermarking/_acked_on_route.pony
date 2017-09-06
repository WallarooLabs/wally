/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "time"
use "wallaroo/core/common"
use "wallaroo/core/invariant"
use "wallaroo/core/routing"

class _AckedOnRoute
  """
  Class used to keep track of acking on a per route basis.
  No route_id is in this class as this class is used as the value in a map.
  """
  var _highest_seq_id_sent: U64 = 0
  var _highest_seq_id_acked: U64 = 0
  var _last_ack: U64 = Time.millis()

  fun ref sent(o_seq_id: SeqId) =>
    ifdef debug then
      Invariant(o_seq_id > _highest_seq_id_sent)
    end

    _highest_seq_id_sent = o_seq_id

  fun ref ack_received(seq_id: SeqId) =>
    ifdef debug then
      Invariant(seq_id <= _highest_seq_id_sent)
    end

    _last_ack = Time.millis()
    _highest_seq_id_acked = seq_id

  fun is_fully_acked(): Bool =>
    _highest_seq_id_sent == _highest_seq_id_acked

  fun highest_seq_id_acked(): U64 =>
    _highest_seq_id_acked

  fun highest_seq_id_sent(): U64 =>
    _highest_seq_id_sent
