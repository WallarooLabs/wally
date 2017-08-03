use "wallaroo/invariant"
use "wallaroo/routing"

class _FilteredOnStep
  """
  Class to keep track of highest message sequence id for this step acker.
  """
  var _highest_seq_id: U64 = 0

  fun ref filter(o_seq_id: SeqId) =>
    ifdef debug then
      Invariant(o_seq_id > _highest_seq_id)
    end

    _highest_seq_id = o_seq_id

  fun is_fully_acked(): Bool =>
    true

  fun highest_seq_id(): U64 =>
    _highest_seq_id
