use "collections"
use "wallaroo/fail"
use "wallaroo/invariant"

class DataReceiverRoutes
  let _filter_route: _FilterRoute ref = recover ref _FilterRoute end
  let _routes: Map[RouteId, _Route] = _routes.create()

  fun ref add_route(route_id: RouteId) =>
    ifdef debug then
      Invariant(not _routes.contains(route_id))
    end

    _routes(route_id) = _Route

  fun ref send(route_id: RouteId, seq_id: SeqId)
  =>
    ifdef debug then
      Invariant(_routes.contains(route_id))
    end

    try
      _routes(route_id).send(seq_id)
    else
      Fail()
    end

  fun ref receive_ack(route_id: RouteId, seq_id: SeqId) =>
    ifdef debug then
      Invariant(_routes.contains(route_id))
      LazyInvariant({()(_routes, route_id, seq_id): Bool ? =>
          _routes(route_id).highest_seq_id_sent() >= seq_id})
    end

    try
      _routes(route_id).receive_ack(seq_id)
    else
      Fail()
    end

  fun unacked_route_ids(): Array[RouteId] =>
    let arr = Array[RouteId]
    for (r_id, r) in _routes.pairs() do
      if not r.is_fully_acked() then
        arr.push(r_id)
      end
    end
    arr

  fun ref propose_new_watermark(): SeqId =>
    _ProposeWatermark(_filter_route, _routes)
