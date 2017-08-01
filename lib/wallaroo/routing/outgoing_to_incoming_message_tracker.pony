use "collections"
use "wallaroo/fail"
use "wallaroo/invariant"

type ProducerRouteSeqId is (Producer, RouteId, SeqId)

class ref OutgoingToIncomingMessageTracker
  let _seq_id_to_incoming: Array[(SeqId, ProducerRouteSeqId)]

  new create(size': USize = 0) =>
    _seq_id_to_incoming = Array[(SeqId, ProducerRouteSeqId)](size')

  fun ref add(o_seq_id: SeqId, i_origin: Producer, i_route_id: RouteId,
    i_seq_id: SeqId)
  =>
    _seq_id_to_incoming.push((o_seq_id, (i_origin, i_route_id, i_seq_id)))

  fun ref evict(through: SeqId) =>
    let n = _index_for(through)
    // magic "not there" value
    if n == -1 then
      return
    end

    _seq_id_to_incoming.remove(0, n + 1)

  fun _origin_highs_below(id: SeqId): MapIs[(Producer, RouteId), U64] =>
    let high_by_origin_route: MapIs[(Producer, RouteId), U64] =
      MapIs[(Producer, RouteId), U64]

    let index: USize = _index_for(id)
    // magic not found index
    if index == -1 then
      return high_by_origin_route
    end

    ifdef debug then
      Invariant(index < _seq_id_to_incoming.size())
    end

    try
      for i in Reverse(index, 0) do
        (let o, let r, let s) = _seq_id_to_incoming(i)._2
        high_by_origin_route.insert_if_absent((o, r), s)
      end
    else
      Fail()
    end

    high_by_origin_route

  fun _index_for(id: SeqId): USize =>
    """
    Find the highest index that is at or below the supplied SeqId.
    Ids in_seq_id_to_incoming ascend monotonically. If this were not
    the case, this code would be horribly broken.
    """
    var seen = USize(-1)
    var i = USize(0)
    let s = _seq_id_to_incoming.size()

    try
      while i < s do
        let rid = _seq_id_to_incoming(i)._1
        if id == rid then
          return i
        elseif id > rid then
          seen = i
        else
          return seen
        end
        i = i + 1
      end
    else
      // unreachable
      seen
    end

    seen

  fun _size(): USize =>
    _seq_id_to_incoming.size()

  fun ref _contains(seq_id: SeqId): Bool =>
    for i in _seq_id_to_incoming.values() do
      if seq_id == i._1 then
        return true
      end
    end

    false
