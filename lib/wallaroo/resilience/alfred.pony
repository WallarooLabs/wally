actor Alfred
    let _log_buffers: Array[EventLogBuffer]

    fun register_log_buffer(logbuffer: EventLogBuffer): U64 =>
        _log_buffers.push(logbuffer)
        _log_buffers.size().u64()

//    fun log(...) =>
//        write logs to file for this log buffer
