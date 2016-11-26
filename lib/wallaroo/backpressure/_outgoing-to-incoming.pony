use "collections"
use "wallaroo/fail"
use "wallaroo/invariant"

class _OutgoingToIncoming
  let _seq_id_to_incoming: Array[(SeqId, ProducerRouteSeqId)] ref

  new create(size': USize = 0) =>
    _seq_id_to_incoming = recover ref
      Array[(SeqId, ProducerRouteSeqId)](size')
    end

  fun size(): USize =>
    _seq_id_to_incoming.size()

  fun ref contains(seq_id: SeqId): Bool =>
    try
      _index_for(seq_id)
      true
    else
      false
    end

  fun ref add(o_seq_id: SeqId,
    i_origin: Producer, i_route_id: RouteId, i_seq_id: SeqId)
  =>
    _seq_id_to_incoming.push((o_seq_id, (i_origin, i_route_id, i_seq_id)))

  fun ref origin_notifications(up_to: SeqId)
    : MapIs[(Producer, RouteId), U64] ?
  =>
    try
      let index = _index_for(up_to)
      _origin_highs_below(index)
    else
      error
    end

  fun ref evict(through: SeqId) ? =>
    let n = _index_for(through) + 1
    _seq_id_to_incoming.remove(0, n)

  fun ref _index_for(id: SeqId): USize ? =>
    """
    Find the index for a given SeqId. We do this
    quickly because, ids in_seq_id_to_incoming
    ascend monotonically. If this were not the case,
    this code would be horribly broken. This code
    also assumes that you will give it a SeqId that
    exists in within the mapping.
    """
    try
      let index = (id - _seq_id_to_incoming(0)._1).usize()
      ifdef "trace" then
        @printf[I32]("id: %llu o: %llu\n".cstring(),
          id, _seq_id_to_incoming(index)._1)
      end
      LazyInvariant({
        ()(_seq_id_to_incoming, index, id): Bool ? =>
        _seq_id_to_incoming(index)._1 <= id})
      LazyInvariant({
        ()(_seq_id_to_incoming, index, id): Bool ? =>
        _seq_id_to_incoming(index)._1 == id})
      index
    else
      error
    end

  fun _origin_highs_below(index: USize): MapIs[(Producer, RouteId), U64] =>
    Invariant(index < _seq_id_to_incoming.size())

    let high_by_origin_route: MapIs[(Producer, RouteId), U64] =
      MapIs[(Producer, RouteId), U64]

    try
      for i in Reverse(index, 0) do
        (let o, let r, let s) = _seq_id_to_incoming(i)._2
        // TODO: add "insert_if_absent" to map
        if not high_by_origin_route.contains((o, r)) then
          high_by_origin_route((o, r)) = s
        end
      end
    else
      Fail()
    end

    high_by_origin_route



