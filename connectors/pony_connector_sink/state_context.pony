use "debug"
use "collections"
use "net"
use "time"

use cwm = "wallaroo_labs/connector_wire_messages"

primitive Phase1Success
  fun bool(): Bool => true

primitive Phase1Fail
  fun bool(): Bool => false

type Phase1Status is (Phase1Success | Phase1Fail)

class StateContext
  let state_machine: SinkStateMachine
  let _conn: TCPConnection
  let active_workers: ActiveWorkers
  let _streams: Map[cwm.StreamId, (cwm.StreamId, cwm.StreamName, cwm.PointOfRef)]
  let _txn_state: Map[String, (Phase1Status, cwm.WhereList)]
  var _worker_name: cwm.WorkerName
  var _output_offset: cwm.PointOfRef
  var _last_committed_offset: cwm.PointOfRef
  var _txn_commit_next: Bool
  var _last_message: (None | cwm.MessageMsg)
  var _next_txn_force_abort_written: Bool
  let _queued_messages: Array[cwm.Message]
  let two_pc_out: TwoPCOutput

  new create(state_machine': SinkStateMachine, conn: TCPConnection, active_workers': ActiveWorkers) =>
    state_machine = state_machine'
    _conn = conn
    active_workers = active_workers'
    _streams = _streams.create()
    _txn_state = _txn_state.create()
    _worker_name = ""
    _output_offset = 0
    _last_committed_offset = 0
    _txn_commit_next = true
    _last_message = None
    _next_txn_force_abort_written = false
    _queued_messages = _queued_messages.create()
    two_pc_out = TwoPCOutputInMemory("")

  fun ref log_it(txn_log_item: TxnLogItem) =>
    let timestamp = Time.seconds().u64()
    two_pc_out.append_txn_log((timestamp, txn_log_item))

  fun ref close() =>
    _conn.dispose()

  fun writev(data: Array[(String val | Array[U8 val] val)] val) =>
    _conn.writev(data)

  fun get_worker_name(): cwm.WorkerName =>
    _worker_name

  fun ref set_worker_name(worker_name: cwm.WorkerName) =>
    _worker_name = worker_name

  fun lookup_stream(stream_id: cwm.StreamId): (cwm.StreamId, cwm.StreamName,
    cwm.PointOfRef) ?
  =>
    _streams(stream_id)?

  fun ref set_stream(stream_id: cwm.StreamId, stream_name: cwm.StreamName,
    point_of_ref: cwm.PointOfRef)
  =>
    _streams(stream_id) = (stream_id, stream_name, point_of_ref)

  fun ref set_streams(streams: Map[cwm.StreamId, (cwm.StreamId, cwm.StreamName, cwm.PointOfRef)] val) =>
    _streams.concat(streams.pairs())

  fun get_sendable_streams(): Map[cwm.StreamId, (cwm.StreamId, cwm.StreamName, cwm.PointOfRef)] iso^ =>
    let sendable_streams = recover iso  Map[cwm.StreamId, (cwm.StreamId, cwm.StreamName, cwm.PointOfRef)] end

    for (k, v) in _streams.pairs() do
      sendable_streams(k) = v
    end

    consume sendable_streams

  fun get_output_offset(): cwm.PointOfRef =>
    _output_offset

  fun ref set_output_offset(point_of_ref: cwm.PointOfRef) =>
    _output_offset = point_of_ref

  fun ref set_stream_output_offset(stream_id: cwm.StreamId, point_of_ref: cwm.PointOfRef) ? =>
    (_, let stream_name, _) = _streams(stream_id)?
    _streams(stream_id) = (stream_id, stream_name, point_of_ref)

  fun compare_output_offset_to(point_of_ref: cwm.PointOfRef): Compare =>
    if _output_offset == point_of_ref then
      Equal
    elseif _output_offset > point_of_ref then
      Greater
    else
      Less
    end

  fun ref set_last_committed_offset(point_of_ref: cwm.PointOfRef) =>
    _last_committed_offset = point_of_ref

  fun ref _set_last_committed_offset_from_transaction_log_lines(transaction_log_lines: Array[TxnLogItem] box) =>
    // TODO: implement this
    None

  fun compare_last_committed_offset_to(point_of_ref: cwm.PointOfRef): Compare =>
    if _last_committed_offset == point_of_ref then
      Equal
    elseif _last_committed_offset > point_of_ref then
      Greater
    else
      Less
    end

  fun ref set_txn_state(txn_id: String, state: (Phase1Status, cwm.WhereList)) =>
    _txn_state(txn_id) = state

  fun ref remove_txn_state(txn_id: String) ? =>
    _txn_state.remove(txn_id)?

  fun ref _reload_phase1_txn_state(transaction_log_lines: Array[TxnLogItem] box) =>
    // TODO: implement this
    None

  fun txn_state_keys(): Iterator[String] =>
    _txn_state.keys()

  fun txn_state_contains(txn_id: String): Bool =>
    _txn_state.contains(txn_id)

  fun ref lookup_txn_state(txn_id: String): (None | (Phase1Status, cwm.WhereList)) =>
    try
      _txn_state(txn_id)?
    else
      None
    end

  fun get_txn_commit_next(): Bool =>
    _txn_commit_next

  fun ref set_txn_commit_next(s: Bool) =>
    _txn_commit_next = false

  fun ref _set_txn_commit_next_from_transaction_log_lines(txn_log: Array[TxnLogItem] box) =>
    // TODO: implement this
    None

  fun ref get_last_message(): (None | cwm.MessageMsg) =>
    _last_message

  fun ref set_last_message(message: cwm.MessageMsg) =>
    _last_message = message

  fun get_next_txn_force_abort_written(): Bool =>
    _next_txn_force_abort_written

  fun ref set_next_txn_force_abort_written(b: Bool) =>
    _next_txn_force_abort_written = b

  fun ref queue_message(m: cwm.Message) =>
    _queued_messages.push(m)

  fun get_queued_messages_values(): Iterator[this->cwm.Message] =>
    _queued_messages.values()

  fun ref clear_queued_messages() =>
    _queued_messages.clear()

  fun ref _set_output_offset_and_truncate_from_transaction_log_lines(txn_log_lines: Array[TxnLogItem] box) ? =>
    var truncate_offset: cwm.PointOfRef = 0

    if _txn_state.size() > 1 then
      Debug("_txn_state.size() > 1")
      error
    end

    if _txn_state.size() == 1 then
      // this will not fail because we have already confirmed that _txn_state.size() == 1
      (let phase1_status, let where_list: cwm.WhereList) = try _txn_state.values().next()? else (Phase1Success, []) end

      if where_list.size() != 1 then
        Debug("bad where_list")
        error
      end

      (let stream_id, let start_por, let end_por) = try where_list(0)? else (0, 0, 0) end

      if stream_id != 1 then
        Debug("Bad where_list")
        error
      end

      if phase1_status is Phase1Success then
        truncate_offset = end_por
      else
        truncate_offset = _last_committed_offset
      end

    elseif _txn_state.size() == 0 then
      truncate_offset = _last_committed_offset
    end

    let truncate_point_of_ref = two_pc_out.truncate_and_seek_to(truncate_offset)

    if truncate_point_of_ref != truncate_offset then
      Debug("truncate got " + truncate_point_of_ref.string() + " expected " + truncate_offset.string())
      error
    end

    _output_offset = truncate_offset

  fun ref update_from_transaction_log_lines(txn_log_lines: Array[TxnLogItem] box) ? =>
    _reload_phase1_txn_state(txn_log_lines)
    _set_txn_commit_next_from_transaction_log_lines(txn_log_lines)
    _set_last_committed_offset_from_transaction_log_lines(txn_log_lines)
    _set_output_offset_and_truncate_from_transaction_log_lines(txn_log_lines)?
