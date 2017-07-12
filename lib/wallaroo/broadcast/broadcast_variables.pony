use "collections"
use "wallaroo/fail"
use "wallaroo/messages"
use "wallaroo/network"

interface tag BroadcastSubscriber
  be broadcast_variable_update(k: String, v: Any val)

actor BroadcastVariables
  var _latest_ts: VectorTimestamp
  let _worker: String
  let _auth: AmbientAuth
  let _broadcast_map: Map[String, (VectorTimestamp, Any val)] =
    _broadcast_map.create()
  let _subs: Map[String, SetIs[BroadcastSubscriber]] = _subs.create()
  let _connections: Connections

  new create(worker: String, auth: AmbientAuth, connections: Connections,
    b_map: Map[String, Any val] val)
  =>
    _latest_ts = VectorTimestamp(worker)
    _worker = worker
    _auth = auth
    for (k, v) in b_map.pairs() do
      _latest_ts = _latest_ts.inc()
      _broadcast_map(k) = (_latest_ts, v)
    end
    for k' in _broadcast_map.keys() do
      _subs(k') = SetIs[BroadcastSubscriber]
    end
    _connections = connections

  be subscribe_to(k: String, sub: BroadcastSubscriber) =>
    try
      sub.broadcast_variable_update(k, _broadcast_map(k)._2)
      _subs(k).set(sub)
    else
      @printf[I32]("Tried to register for nonexistent broadcast variable %s\n"
        .cstring(), k.cstring())
    end

  be update(k: String, v: Any val, source: BroadcastSubscriber) =>
    try
      let latest_ts = _broadcast_map(k)._1.inc()

      _broadcast_map(k) = (latest_ts, v)
      for s in _subs(k).values() do
        if s isnt source then
          s.broadcast_variable_update(k, v)
        end
      end

      try
        let msg = ChannelMsgEncoder.broadcast_variable(k, v, latest_ts,
          _worker, _auth)
        _connections.send_control_to_cluster(msg)
      else
        Fail()
      end
    else
      @printf[I32]("Tried to update nonexistent broadcast variable %s\n"
        .cstring(), k.cstring())
    end

  be external_update(k: String, v: Any val, ts: VectorTimestamp,
    source_worker: String)
  =>
    if _broadcast_map.contains(k) then
      try
        (let cur_ts, let cur_v) = _broadcast_map(k)
        if not cur_ts.is_comparable(ts) then
          _latest_ts = cur_ts.merge(ts).inc()

          if source_worker > _worker then
            _broadcast_map(k) = (ts, v)
          end
          _broadcast_map
        else
          if cur_ts < ts then
            _broadcast_map(k) = (ts, v)
            for s in _subs(k).values() do
              s.broadcast_variable_update(k, v)
            end
          end
        end
      else
        Fail()
      end
    else
      try
        _broadcast_map(k) = (ts, v)
        for s in _subs(k).values() do
          s.broadcast_variable_update(k, v)
        end
      else
        Fail()
      end
    end


