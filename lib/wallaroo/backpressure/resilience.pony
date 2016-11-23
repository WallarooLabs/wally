use "assert"
use "collections"
use "time"
use "wallaroo/topology"
use "sendence/guid"

type SeqId is U64
type RouteId is U64

primitive HashOrigin
  fun hash(o: Origin): U64 =>
    o.hash()

  fun eq(o1: Origin, o2: Origin): Bool =>
    o1.hash() == o2.hash()

  fun ne(o1: Origin, o2: Origin): Bool =>
    o1.hash() != o2.hash()

trait tag Origin
  fun tag hash(): U64 =>
    (digestof this).hash()

  fun ref flushing(): Bool
  fun ref not_flushing()
  fun ref watermarks(): Watermarks
  fun ref hwmt(): HighWatermarkTable
  fun ref _watermarks_counter(): U64

  fun ref _flush(low_watermark: SeqId, origin: Origin,
    upstream_route_id: RouteId , upstream_seq_id: SeqId)

  be log_flushed(low_watermark: SeqId, i_origin: Origin,
    i_route_id: RouteId, i_seq_id: SeqId)
  =>
    """
    We will be called back here once the eventlogs have been flushed for a
    particular origin. We can now send the low watermark upstream to this
    origin.
    """
    // flush succeeds, so update low watermark per origin
    not_flushing()
    watermarks().update_low_watermark(i_origin, low_watermark)
    // send low watermark upstream
    i_origin.update_watermark(i_route_id, i_seq_id)

  fun ref _bookkeeping(o_route_id: RouteId, o_seq_id: SeqId, i_origin: Origin,
    i_route_id: RouteId, i_seq_id: SeqId, msg_uid: U128)
  =>
    """
    Process envelopes and keep track of things
    """
    ifdef "resilience" then //TODO: fix other "resilience-debug" entries
      ifdef "trace" then
        @printf[I32]((
        "bookkeeping envelope:\no_route_id: " +
        o_route_id.string() +
        "\to_seq_id: " +
        o_seq_id.string() +
        "\ti_origin: " +
        i_origin.hash().string() +
        "\ti_route_id: " +
        i_route_id.string() +
        "\ni_seq_id: " +
        i_seq_id.string() +
        "\tmsg_uid: " +
        msg_uid.string() +
        "\n\n").cstring())
      end
    end

    hwmt().update(o_seq_id, (i_origin, i_route_id, i_seq_id))
    watermarks().add_sent(o_route_id, o_seq_id)

  be update_watermark(route_id: RouteId, seq_id: SeqId) =>
  """
  Process a high watermark received from a downstream step.
  """
    _update_watermark(route_id, seq_id)

  fun ref _update_watermark(route_id: RouteId, seq_id: SeqId) =>
    ifdef "trace" then
      @printf[I32]((
      "update_watermark: " +
      "route_id: " + route_id.string() +
      "\tseq_id: " + seq_id.string() + "\n\n").cstring())
    end

    /*
    ifdef debug then
      try
        Assert(hwmt().contains(seq_id),
          "Invariant violated: hwmt().contains(seq_id)")
       else
        //TODO: how do we bail out here?
        None
      end
    end
    */

    try
      (let i_origin, let i_route_id, let i_seq_id) =
        hwmt().get_and_remove(seq_id)
      watermarks().add_high_watermark(route_id, seq_id)

      if ((_watermarks_counter() % 1000) == 0) then
        _run_ack(i_origin, i_route_id, i_seq_id)
      end
    else
      //TODO: how do we bail out here?
      None
    end

  fun ref _run_ack(i_origin: Origin, i_route_id: RouteId, i_seq_id: SeqId) ? =>
    if not flushing() then

      ifdef "trace" then
        @printf[I32]("_run_ack: we're not flushing yet. Flushing now.\n\n".cstring())
      end

      @printf[None]("Running ack\n".cstring())
      let lowest_watermark = watermarks().low_watermark_for(i_origin)
      _flush(lowest_watermark, i_origin, i_route_id , i_seq_id)
    end


type OriginRouteSeqId is (Origin, RouteId, SeqId)

type RouteLastWatermark is Map[RouteId, SeqId]

class HighWatermarkTable
  let id: U64 = GuidGenerator.u64()
  let _hwmt: Map[SeqId, OriginRouteSeqId] = _hwmt.create()

  fun ref update(o_seq_id: SeqId, tuple: OriginRouteSeqId)
  =>
    _hwmt(o_seq_id) = tuple

  fun ref get_and_remove(o_seq_id: SeqId): OriginRouteSeqId ? =>
    ifdef debug then
      try
        Assert(_hwmt.contains(o_seq_id),
        "Invariant violated: _hwmt.contains(o_seq_id) for id: " + id.string())
      else
        //TODO: how do we bail out here?
        None
      end
    end

    try
      (let k, let v) = _hwmt.remove(o_seq_id)
      v
    else
      //TODO: bail out, we failed.
      //This can only happen if we never registered a tuple
      //for this o_seq_id
      error
    end

  fun contains(seq_id: SeqId): Bool =>
    _hwmt.contains(seq_id)

class RouteTracker
  var highest_sent: SeqId = 0
  var highest_acked: SeqId = 0


class Watermarks
  let id: U64 = GuidGenerator.u64()
  let _route_trackers: Map[RouteId, RouteTracker] = _route_trackers.create()
  let _low_watermarks: HashMap[Origin, U64, HashOrigin] = _low_watermarks.create()
  //TODO: use MapIs

  fun low_watermark_for(origin: Origin): U64 =>
    var not_fully_acked = false
    var low = try _low_watermarks(origin)
    else
      @printf[None]("We shouldnt keep seeing this\n".cstring())
      U64.max_value()
    end
    var high: U64 = 0
    for route_tracker in _route_trackers.values() do
      if route_tracker.highest_sent > route_tracker.highest_acked then
        not_fully_acked = true
        if route_tracker.highest_acked < low then
          low = route_tracker.highest_acked
        end
      else
        if route_tracker.highest_acked > high then
          high = route_tracker.highest_acked
        end
      end
    end
    if not_fully_acked then
      low
    else
      high
    end

  fun ref add_high_watermark(o_route_id: RouteId, o_seq_id: SeqId) =>
    let route_tracker = try
      _route_trackers(o_route_id)
    else
      //TODO: we need to bail out here
      @printf[I32]((
        "add_high_watermark: _route_trackers() lookup failed for: " +
        o_route_id.string() + " on id: " + id.string() + "\n\n").cstring())
      None
    end

    ifdef debug then
      try
        ifdef "trace" then
          @printf[I32](("add_high_watermark: o_route_id: " +
          o_route_id.string() + "\n\n").cstring())
        end
        Assert(route_tracker isnt None,
          "Invariant violated: route_tracker isn't None")
        match route_tracker
        | let rt: RouteTracker => Assert(o_seq_id > rt.highest_acked,
          "Invariant violated: o_seq_id > route_tracker.highest_acked")
        end
      else
        //TODO: how do we bail out here?
        None
      end
    end

    match route_tracker
    | let rt: RouteTracker => rt.highest_acked = o_seq_id
    else
      //TODO: how do we bail out here?
      None
    end

  fun ref add_sent(o_route_id: RouteId, o_seq_id: SeqId) =>
    let route_tracker = try
      _route_trackers(o_route_id)
    else
      let new_route_tracker = create_route_tracker()
      _route_trackers(o_route_id) = new_route_tracker
      new_route_tracker
    end

    ifdef debug then
      try
        Assert(o_seq_id > route_tracker.highest_sent,
          "Invariant violated: o_seq_id > route_tracker.highest_sent")
        end
      else
        //TODO: how do we bail out here?
        None
      end

    route_tracker.highest_sent = o_seq_id

  fun ref update_low_watermark(i_origin: Origin, low_watermark: SeqId) =>
    _low_watermarks(i_origin) = low_watermark

  fun ref create_route_tracker(): RouteTracker =>
    RouteTracker.create()


primitive HashTuple
  fun hash(t: (U64, U64)): U64 =>
    cantorPair(t)

  fun eq(t1: (U64, U64), t2: (U64, U64)): Bool =>
    cantorPair(t1) == cantorPair(t2)

  fun cantorPair(t: (U64, U64)): U64 =>
    (((t._1 + t._2) * (t._1 + t._2 + 1)) / 2 )+ t._2
