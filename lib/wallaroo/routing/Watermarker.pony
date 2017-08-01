use "collections"
use "wallaroo/fail"
use "wallaroo/invariant"

class ref Watermarker
  """
  Tracks watermarks across all routes so we can propose a new watermark.
  """
  let _filter_route: _FilterRoute = _FilterRoute
  let _routes: Map[RouteId, _Route] = _routes.create()

  fun ref add_route(id: RouteId) =>
    ifdef debug then
      Invariant(not _routes.contains(id))
    end

    if not _routes.contains(id) then
        _routes(id) = _Route
    end

  fun ref remove_route(id: RouteId) =>
    try
      let old_route = _routes(id)
      ifdef debug then
        // We currently assume stop the world and finishing all in-flight
        // processing before any route migration.
        Invariant(old_route.is_fully_acked())
      end

      _routes.remove(id)
    else
      Fail()
    end

  fun ref sent(o_route_id: RouteId, o_seq_id: SeqId) =>
    ifdef debug then
      Invariant(_routes.contains(o_route_id))
    end

    try
      _routes(o_route_id).send(o_seq_id)
    else
      Fail()
    end

  fun ref filtered(o_seq_id: SeqId) =>
    """
    Filter out a message or otherwise have this be the end of the line
    """
    _filter_route.filter(o_seq_id)

  fun ref ack_received(route_id: RouteId, seq_id: SeqId) =>
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

  fun ref propose_watermark(): U64 =>
    _ProposeWatermark(_filter_route, _routes)

  fun unacked_route_ids(): Array[RouteId] =>
    let arr = Array[RouteId]
    for (r_id, r) in _routes.pairs() do
      if not r.is_fully_acked() then
        arr.push(r_id)
      end
    end
    arr
