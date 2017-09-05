/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "wallaroo/core"
use "wallaroo/invariant"
use "wallaroo/routing"

class _FilteredOnStep
  """
  Class to keep track of highest message sequence id for this step acker.
  """
  var _highest_seq_id: U64 = 0

  fun ref filtered(o_seq_id: SeqId) =>
    ifdef debug then
      Invariant(o_seq_id > _highest_seq_id)
    end

    _highest_seq_id = o_seq_id

  fun is_fully_acked(): Bool =>
    true

  fun highest_seq_id(): U64 =>
    _highest_seq_id
