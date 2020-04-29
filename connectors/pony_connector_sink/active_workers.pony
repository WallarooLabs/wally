use "collections"

use cwm = "wallaroo_labs/connector_wire_messages"

actor ActiveWorkers
  let _worker_names: Set[cwm.WorkerName]

  let _worker_streams: Map[cwm.WorkerName, Map[cwm.StreamId, (cwm.StreamId, cwm.StreamName, cwm.PointOfRef)] val]

  new create() =>
    _worker_names = _worker_names.create()
    _worker_streams = _worker_streams.create()

  be add_new_worker(worker_name: cwm.WorkerName, sm: SinkStateMachine, hello: cwm.HelloMsg val) =>
    if _worker_names.contains(worker_name) then
      sm.deny_new_worker(hello)
    else
      _worker_names.set(worker_name)

      let worker_streams =
        _worker_streams.get_or_else(worker_name, recover val Map[cwm.StreamId, (cwm.StreamId, cwm.StreamName, cwm.PointOfRef)] end)

      sm.approve_new_worker(hello, worker_streams)
    end

  be remove_worker(worker_name: cwm.WorkerName, streams: Map[cwm.StreamId, (cwm.StreamId, cwm.StreamName, cwm.PointOfRef)] val) =>
    _worker_names.unset(worker_name)
    _worker_streams(worker_name) = streams

  be workers_left(worker_names: Array[cwm.WorkerName] val) =>
    for wn in worker_names.values() do
      try
        // Every connectoin will receive the same message and try to remove
        // these entries, so the first one to get here will succeed and the rest
        // will fail, which is fine.
        _worker_streams.remove(wn)?
      end
    end
