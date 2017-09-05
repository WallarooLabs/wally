/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "wallaroo/ent/network"
use "wallaroo/fail"
use "wallaroo/messages"

interface tag BroadcastSubscriber
  be broadcast_variable_update(k: String, v: Any val)

actor BroadcastVariables
  let _worker: String
  let _auth: AmbientAuth
  let _broadcast_map: BroadcastVariablesMap
  let _subs: Map[String, SetIs[BroadcastSubscriber]] = _subs.create()
  let _connections: Connections

  new create(worker: String, auth: AmbientAuth, connections: Connections,
    b_map: Map[String, Any val] val)
  =>
    _worker = worker
    _auth = auth
    _broadcast_map = BroadcastVariablesMap(_worker, b_map)
    for k' in _broadcast_map.keys() do
      _subs(k') = SetIs[BroadcastSubscriber]
    end
    _connections = connections

  be subscribe_to(k: String, sub: BroadcastSubscriber) =>
    try
      sub.broadcast_variable_update(k, _broadcast_map(k))
      _subs(k).set(sub)
    else
      @printf[I32]("Tried to register for nonexistent broadcast variable %s\n"
        .cstring(), k.cstring())
    end

  be update(k: String, v: Any val, source: BroadcastSubscriber) =>
    try
      let latest_ts = _broadcast_map.update(k, v)

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
    let applied_change = _broadcast_map.external_update(k, v, ts,
      source_worker)
    if applied_change then
      try
        for s in _subs(k).values() do
          s.broadcast_variable_update(k, v)
        end
      else
        Fail()
      end
    end
