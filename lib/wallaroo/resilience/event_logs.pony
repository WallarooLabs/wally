class LogEntry
    let _uid: U64
    let _fractional_list: Array[U64] val
    let _statechange_id: U64
    let _contents: Array[U8] val
    let _last_fractional_child: U64

    new create(uid: U64, fractional_list: Array[U64] val, statechange_id: U64,
        contents: Array[U8] val) =>
        _uid = uid
        _fractional_list = fractional_list
        _statechange_id = statechange_id

    fun is_below_watermark(watermark: U64) =>
    //TODO: this will have to change once we have a Watermark type
        _uid < watermark

trait EventLogBuffer
    fun ref log(log_entry: LogEntry)
    fun flush(watermark: U64)

class NoEventLogBuffer is EventLogBuffer
    fun ref log(log_entry: LogEntry)
        None

    fun flush() =>
        None

class StandardEventLogBuffer is EventLogBuffer
    var _buf: Array[LogEntry val]
    let _alfred: Alfred
    let _id: U64

    new create(alfred: Alfred) =>
        _buf = Array[Array[U8] val]
        _alfred = alfred
        _id = _alfred.register_log_buffer(this)

    fun ref log(log_entry: LogEntry)
        _buf.push(log_entry))

    fun flush(watermark: U64) =>
        let _out_buf: Array[LogEntry val]
        let _new_buf: Array[LogEntry val]
        for entry in _buf.values() do
            if entry.is_below_watermark(watermark) then
                _out_buf.push(entry)
            else
                _new_buf.push(entry)
            end
        done
        _alfred.log(_id,_out_buf)
        _buf = _new_buf
