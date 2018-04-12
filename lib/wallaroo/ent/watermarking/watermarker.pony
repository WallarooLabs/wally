/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "wallaroo/core/common"
use "wallaroo_labs/mort"
use "wallaroo/core/invariant"
use "wallaroo/core/routing"

class ref Watermarker
  """
  Tracks watermarks across all routes so we can propose a new watermark.
  """
  let _filtered: _FilteredOnStep = _FilteredOnStep
  let _routes: Map[RouteId, _AckedOnRoute] = _routes.create()

  fun ref add_route(id: RouteId) =>
    if not _routes.contains(id) then
        _routes(id) = _AckedOnRoute
    end

  fun contains_route(id: RouteId): Bool =>
    _routes.contains(id)

  fun ref remove_route(id: RouteId) =>
    try
      let old_route = _routes(id)?
      ifdef debug then
        // We currently assume stop the world and finishing all in-flight
        // processing before any route migration.
        Invariant(old_route.is_fully_acked())
      end

      _routes.remove(id)?
    else
      Fail()
    end

  fun routes_size(): USize =>
    _routes.size()

  fun ref sent(o_route_id: RouteId, o_seq_id: SeqId) =>
    ifdef debug then
      Invariant(_routes.contains(o_route_id))
    end

    try
      _routes(o_route_id)?.sent(o_seq_id)
    else
      Fail()
    end

  fun ref filtered(o_seq_id: SeqId) =>
    """
    Filter out a message or otherwise have this be the end of the line
    """
    _filtered.filtered(o_seq_id)

  fun ref ack_received(route_id: RouteId, seq_id: SeqId) =>
    ifdef debug then
      Invariant(_routes.contains(route_id))
      LazyInvariant({()(_routes, route_id, seq_id): Bool ? =>
          _routes(route_id)?.highest_seq_id_sent() >= seq_id})
    end

    try
      _routes(route_id)?.ack_received(seq_id)
    else
      Fail()
    end

  fun ref propose_watermark(): U64 =>
    _ProposeWatermark(_filtered, _routes)

  fun unacked_route_ids(): Array[RouteId] =>
    let arr = Array[RouteId]
    for (r_id, r) in _routes.pairs() do
      if not r.is_fully_acked() then
        arr.push(r_id)
      end
    end
    arr
