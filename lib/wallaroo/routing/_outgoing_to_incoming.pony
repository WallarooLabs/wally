use "collections"
use "wallaroo/fail"
use "wallaroo/invariant"
use "wallaroo/topology"

type ProducerRouteSeqId is (Producer, RouteId, SeqId)

class _OutgoingToIncoming
  let _seq_id_to_incoming: Array[(SeqId, ProducerRouteSeqId)] ref
  let _highest_outgoing_seen: MapIs[ProducerRouteSeqId, SeqId] ref

  new create(size': USize = 0) =>
    _seq_id_to_incoming = recover ref
      Array[(SeqId, ProducerRouteSeqId)](size')
    end
    _highest_outgoing_seen = recover ref
      MapIs[ProducerRouteSeqId, SeqId](size')
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
    // ASSUMPTION: given the monotonic nature of outgoing sequence ids, we will
    // get ever increasing values for o_seq_id
    _seq_id_to_incoming.push((o_seq_id, (i_origin, i_route_id, i_seq_id)))
    ifdef "onetomany" then
      _highest_outgoing_seen.update((i_origin, i_route_id, i_seq_id), o_seq_id)
    else
      _highest_outgoing_seen.update((i_origin, 1, 1), o_seq_id)
    end

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
      let low_id = _seq_id_to_incoming(0)._1
      if id >= low_id then
        let index = (id - low_id).usize()
        ifdef debug then
          LazyInvariant({
            ()(_seq_id_to_incoming, index, id): Bool ? =>
            _seq_id_to_incoming(index)._1 == id})
        end
        index
      else
        error
      end
    else
      error
    end

  fun ref _origin_highs_below(index: USize): MapIs[(Producer, RouteId), U64] =>
    ifdef debug then
      Invariant(index < _seq_id_to_incoming.size())
    end

    let high_by_origin_route: MapIs[(Producer, RouteId), U64] =
      MapIs[(Producer, RouteId), U64]

    ifdef "onetomany" then
      try
        ifdef "onetomany1" then
          for i in Reverse(index, 0) do
            (let outgoing_id, (let o, let r, let s)) = _seq_id_to_incoming(i)
            if outgoing_id == _highest_outgoing_seen((o, r, s)) then
              high_by_origin_route.insert_if_absent((o, r), s)
            end
          end
        end

        ifdef "onetomany2" then
          for i in Range(0, index + 1) do
            (let outgoing_id, (let o, let r, let s)) = _seq_id_to_incoming(i)

            if outgoing_id == _highest_outgoing_seen((o, r, s)) then
              // only ack this message if we are seeing its highest value
              high_by_origin_route.update((o, r), s)
              _highest_outgoing_seen.remove((o, r, s))
            end
          end
        end
      else
        Fail()
      end
    else
      try
        for i in Reverse(index, 0) do
          (let o, let r, let s) = _seq_id_to_incoming(i)._2
          high_by_origin_route.insert_if_absent((o, r), s)
        end
      else
        Fail()
      end
    end

    high_by_origin_route



