use "buffered"
use "debug"

use cwm = "wallaroo_labs/connector_wire_messages"

primitive HandleNotifyMsg
  fun apply(ctx: StateContext, notify: cwm.NotifyMsg): (SinkState | None) =>
    if notify.stream_id != 1 then
      Debug("Unsupported stream id " + notify.stream_id.string())
      let err = cwm.ErrorMsg("Unsupported stream id " + notify.stream_id.string())
      ctx.writev(err.encode().done())
      return InvalidState
    end

    let point_of_ref = try
      ctx.lookup_stream(notify.stream_id)?._3
    else
      0
    end

    ctx.set_stream(notify.stream_id, notify.stream_name, point_of_ref)

    let notify_ack = cwm.NotifyAckMsg(true, notify.stream_id, point_of_ref)
    ctx.writev(notify_ack.encode().done())

    None

primitive HandleErrorMsg
  fun apply(ctx: StateContext, err: cwm.ErrorMsg) =>
    Debug("Recieved an error message, closing the connection")
    ctx.close()

    ctx.active_workers.remove_worker(ctx.get_worker_name(), ctx.get_sendable_streams())

primitive HandleMessageMsg
  fun apply(ctx: StateContext, message: cwm.MessageMsg) =>
    (let bytes_size: USize, let message_message: Array[U8] val) = match message.message
    | let mbs: cwm.MessageBytes =>
      mbs.size()
      let s = match mbs
      | let ms: String =>
        ms.array()
      | let ma: Array[U8] val =>
        ma
      end
      (mbs.size(), s)
    | let bsi: ByteSeqIter =>
      var size: USize = 0
      for bs in bsi.values() do
        size = size + bs.size()
      end
      (size, recover Array[U8] end)
    | None =>
      (0, recover Array[U8] end)
    end

    if message.message_id isnt None then
      match ctx.compare_output_offset_to(message.message_id)
      | Equal =>
        Debug("offset == message_id")
        try
          (let ret1, let new_offset) = ctx.two_pc_out.append_output(message_message)?
          ctx.set_output_offset(new_offset)
          ctx.set_stream_output_offset(message.stream_id, new_offset)?
        else
          ctx.set_txn_commit_next(false)
        end
      | Less =>
        Debug(" ".join([as Stringable: "offset"; ctx.get_output_offset(); "< message_id"; message.message_id.string()].values()))
        Debug("message: '" + String.from_array(message_message) + "'")
        ctx.set_txn_commit_next(false)
        if not ctx.get_next_txn_force_abort_written() then
          ctx.set_next_txn_force_abort_written(true)
          ctx.log_it(NextTxnForceAbort("MISSING DATA: offset < message_id " + message.message_id.string() + " worker " + ctx.get_worker_name()))
        end

        if ctx.get_last_message() is None then
          Debug("got message after a gap")
        elseif not ctx.get_next_txn_force_abort_written() then
          Debug("this is bad")
          // TODO: More logging here?
          // TODO: exit here, or go to invalid state?
        end
      | Greater =>
        Debug("offset > message_id")
        ctx.set_txn_commit_next(false)
        ctx.two_pc_out.flush_fsync_all()
        // TODO: exit here, or go to invalid state?
      end
    else
      Debug("message has no message_id")
      // TODO: exit here, or go to invalid state?
    end

    ctx.set_last_message(message)

primitive HandleEosMsg
  fun apply(ctx: StateContext, eos: cwm.EosMessageMsg) =>
    Debug("acking eos")
    try
      (_, _, let point_of_ref) = ctx.lookup_stream(eos.stream_id)?
      ctx.writev(cwm.AckMsg(1, [(eos.stream_id, point_of_ref)]).encode().done())
    else
      Debug("Could not find stream id=" + eos.stream_id.string() + " for EOS message")
    end

primitive Handle2PCPhase1Msg
  fun apply(ctx: StateContext, message: cwm.TwoPCPhase1Msg): SinkState =>
    if ctx.compare_output_offset_to(ctx.two_pc_out.out_tell()) isnt Equal then
      ctx.set_txn_commit_next(false)
      Debug("2PC: sanity: offset != tell")
      return InvalidState
    end

    for (stream_id, start_point_of_ref, end_point_of_ref) in message.where_list.values() do
      if stream_id != 1 then
        ctx.set_txn_commit_next(false)
        Debug("2PC: Phase 1 invalid stream_id")
      end

      if ctx.compare_last_committed_offset_to(start_point_of_ref) isnt Equal then
        ctx.set_txn_commit_next(false)
        Debug("2PC: Phase 1 invalid start point of reference")
      end

      if start_point_of_ref > end_point_of_ref then
        ctx.set_txn_commit_next(false)
        Debug("2PC: Phase 1 start point of reference > end point of reference")
      end

      if ctx.compare_output_offset_to(end_point_of_ref) isnt Less then
        ctx.set_txn_commit_next(false)
        let m = "2PC: Phase 1 end point of reference > end point of reference"
        if ctx.compare_output_offset_to(start_point_of_ref) is Equal then
          Debug(m)
        else
          Debug(m + "THIS IS BAD")
          ctx.log_it(NextTxnForceAbort(m))
          return ErrorState
        end
      end
    end

    let wl_i: cwm.WhereList iso = (recover iso cwm.WhereList.create() end)
    let wl: cwm.WhereList val  = consume wl_i

    let success = if ctx.get_txn_commit_next() then
      Phase1Success
    else
      Phase1Fail
    end

    ctx.set_txn_state(message.txn_id, (success, message.where_list))

    match success
    | Phase1Success =>
      ctx.log_it(PhaseOneOk(message.txn_id, wl))
    else
      ctx.log_it(PhaseOneRollback(message.txn_id, wl))
    end

    let reply = cwm.TwoPCReplyMsg(message.txn_id, success.bool())
    let reply_bytes = cwm.TwoPCFrame.encode(reply)
    ctx.writev(cwm.MessageMsg(0, 0, 0, None, reply_bytes).encode().done())

    AwaitMessageOr2PCPhase2State

primitive Handle2PCPhase2Msg
  fun apply(ctx: StateContext, message: cwm.TwoPCPhase2Msg): SinkState =>
    match ctx.lookup_txn_state(message.txn_id)
    | (let phase1_status: Phase1Status, let where_list: cwm.WhereList) =>
      Debug("got 2PC phase 2 message")
      if not message.commit then
        for (stream_id, start_point_of_ref, end_point_of_ref) in where_list.values() do
          Debug("going through where_list")
          if stream_id != 1 then
            Debug("Phase 2 abort: bad stream_id")
            return ErrorState
          end

          ctx.two_pc_out.flush_fsync_out()
          // TODO: copy output log for diagnostics

          ctx.two_pc_out.flush_fsync_out()
          let t_point_of_ref = ctx.two_pc_out.truncate_and_seek_to(start_point_of_ref)

          if t_point_of_ref != start_point_of_ref then
            Debug("truncate got " + t_point_of_ref.string() + " expected " + start_point_of_ref.string())
            return ErrorState
          end

          ctx.set_output_offset(start_point_of_ref)

          try
            // In case of disconnect, reconnect, and ReplyUncommitted's list of
            // txns is not empty, then when the phase 2 abort arrives, we have
            // not seen a Notify message for the stream id, this attempt to
            // update the offset will raise an error, which is ok here.
            ctx.set_stream_output_offset(stream_id, start_point_of_ref)?
          end
        end
      end

      if (phase1_status isnt Phase1Success) and message.commit then
        // TODO: Log and exit or something?
        Debug("2PC: Protocol error: phase 1 status was rollback but phase 2 says commit")
        return ErrorState
      end

      let log_item = if message.commit then
        try
          let offset = where_list(0)?._3

          ctx.set_last_committed_offset(offset)

          PhaseTwoOk(message.txn_id, offset)
        else
          Debug("2PC: empty where_list in commit")
          return ErrorState
        end
      else
        try
          let offset = where_list(0)?._2

          if ctx.compare_output_offset_to(offset) isnt Equal then
            Debug("2PC: phase 2 offset != output_offset")
          end

          ctx.set_last_committed_offset(offset)

          PhaseTwoRollback(message.txn_id, offset)
        else
          Debug("2PC: empty where_list in rollback")
          return ErrorState
        end
      end

      ctx.log_it(log_item)

      try
        ctx.remove_txn_state(message.txn_id)?
      else
        Debug("could not remove txn " + message.txn_id.string() + " from txn_state")
      end
    else
      Debug("2PC: Phase 2 got unknown txn_id " + message.txn_id + " commit " + message.commit.string())
      ctx.log_it(PhaseTwoError(message.txn_id, "unknown txn_id, commit " + message.commit.string()))
    end

    AwaitMessageOr2PCPhase1State

primitive HandleListUncommittedMsg
  fun apply(ctx: StateContext, message: cwm.ListUncommittedMsg) =>
    Debug("List uncommitted messages")

    let uncommitted = recover iso Array[String] end

    for txn_id in ctx.txn_state_keys() do
      uncommitted.push(txn_id)
    end

    let reply = cwm.ReplyUncommittedMsg(message.rtag, consume uncommitted)
    let reply_bytes = cwm.TwoPCFrame.encode(reply)
    ctx.writev(cwm.MessageMsg(0, 0, 0, None, reply_bytes).encode().done())

primitive HandleWorkersLeftMsg
  fun apply(ctx: StateContext, message: cwm.WorkersLeftMsg) =>
    let lw: Array[cwm.WorkerName] val = (recover iso Array[cwm.WorkerName] end) .> append(message.leaving_workers)
    ctx.active_workers.workers_left(lw)
    ctx.two_pc_out.leaving_workers(lw)
