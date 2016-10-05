actor Alfred
    let _log_buffers: Array[EventLogBuffer tag]

    new create() =>
      _log_buffers = Array[EventLogBuffer tag]

    be register_log_buffer(logbuffer: EventLogBuffer tag) =>
      _log_buffers.push(logbuffer)
      let id = _log_buffers.size().u64()
      logbuffer.set_id(id)

    be log(id: U64, log_entries: Array[LogEntry val] iso) =>
//        write logs to file for this log buffer
      None
