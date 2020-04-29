use "collections"
use "debug"

use cwm = "wallaroo_labs/connector_wire_messages"

trait val SinkState
  fun handle_hello(ctx: StateContext, hello: cwm.HelloMsg): SinkState => InvalidState
  fun handle_ok(ctx: StateContext, ok: cwm.OkMsg): SinkState => InvalidState
  fun handle_error(ctx: StateContext, err: cwm.ErrorMsg): SinkState => InvalidState
  fun handle_notify(ctx: StateContext, notify: cwm.NotifyMsg): SinkState => InvalidState
  fun handle_notify_ack(ctx: StateContext, notify_ack: cwm.NotifyAckMsg): SinkState => InvalidState
  fun handle_message(ctx: StateContext, message: cwm.MessageMsg): SinkState => InvalidState
  fun handle_eos(ctx: StateContext, eos: cwm.EosMessageMsg): SinkState => InvalidState
  fun handle_ack(ctx: StateContext, ack: cwm.AckMsg): SinkState => InvalidState
  fun handle_restart(ctx: StateContext, restart: cwm.RestartMsg): SinkState => InvalidState
  fun handle_workers_left(ctx: StateContext, workers_left: cwm.WorkersLeftMsg): SinkState => InvalidState

  fun handle_approve_new_worker(ctx: StateContext,
    hello: cwm.HelloMsg val,
    streams: Map[cwm.StreamId, (cwm.StreamId, cwm.StreamName, cwm.PointOfRef)] val): SinkState
  =>
    InvalidState

  fun handle_deny_new_worker(ctx: StateContext, hello: cwm.HelloMsg val): SinkState => InvalidState

  fun string(): String iso^

primitive DebugState is SinkState
  """
  This state just tries to return an appropriate message based on the message it received.
  """
  fun handle_hello(ctx: StateContext, hello: cwm.HelloMsg): SinkState =>
    Debug("Got HELLO")
    let msg = cwm.OkMsg(500)
    ctx.writev(msg.encode().done())
    DebugState

  fun handle_ok(ctx: StateContext, ok: cwm.OkMsg): SinkState =>
    Debug("Got OK")
    DebugState

  fun handle_error(ctx: StateContext, err: cwm.ErrorMsg): SinkState =>
    Debug("Got ERROR")
    DebugState

  fun handle_notify(ctx: StateContext, notify: cwm.NotifyMsg): SinkState =>
    Debug("Got NOTIFY")
    DebugState

  fun handle_notify_ack(ctx: StateContext, notify_ack: cwm.NotifyAckMsg): SinkState =>
    Debug("Got NOTIFY_ACK")
    DebugState

  fun handle_message(ctx: StateContext, message: cwm.MessageMsg): SinkState =>
    Debug("Got MESSAGE")
    DebugState

  fun handle_eos(ctx: StateContext, eos: cwm.EosMessageMsg): SinkState =>
    Debug("Got EOS")
    DebugState

  fun handle_ack(ctx: StateContext, ack: cwm.AckMsg): SinkState =>
    Debug("Got ACK")
    DebugState

  fun handle_restart(ctx: StateContext, restart: cwm.RestartMsg): SinkState =>
    Debug("Got RESTART")
    DebugState

  fun handle_workers_left(ctx: StateContext, workers_left: cwm.WorkersLeftMsg): SinkState =>
    Debug("Got WORKERS_LEFT")
    DebugState

  fun string(): String iso^ => "DebugState".clone()

primitive InvalidState is SinkState
  fun string(): String iso^ => "InvalidState".clone()

primitive InitialState is SinkState
  fun handle_hello(ctx: StateContext, hello: cwm.HelloMsg): SinkState =>
    if hello.version != "v0.0.1" then
      Debug("bad protocol version" + hello.version)
      return InvalidState
    end

    if hello.cookie != "Dragons-Love-Tacos" then
      Debug("bad cookie: " + hello.cookie)
      return InvalidState
    end

    Debug("Hello message from worker " + hello.instance_name)

    let version = hello.version
    let cookie = hello.cookie
    let program_name = hello.program_name
    let instance_name = hello.instance_name

    let hello_val = recover val cwm.HelloMsg(version, cookie, program_name, instance_name) end

    ctx.active_workers.add_new_worker(hello.instance_name, ctx.state_machine, hello_val)

    AwaitApproveOrDenyWorkerState

  fun handle_error(ctx: StateContext, err: cwm.ErrorMsg): SinkState =>
    HandleErrorMsg(ctx, err)
    ErrorState

  fun string(): String iso^ => "InitialState".clone()

primitive AwaitApproveOrDenyWorkerState is SinkState
  fun handle_approve_new_worker(ctx: StateContext,
    hello: cwm.HelloMsg val,
    streams: Map[cwm.StreamId,
    (cwm.StreamId, cwm.StreamName, cwm.PointOfRef)] val): SinkState
  =>
    let ok = cwm.OkMsg(500)

    ctx.writev(ok.encode().done())

    ctx.set_worker_name(hello.instance_name)

    ctx.set_output_offset(ctx.two_pc_out.open(hello.instance_name))

    ctx.set_streams(streams)

    let transaction_log_lines = ctx.two_pc_out.read_txn_log_lines()

    try
      ctx.update_from_transaction_log_lines(transaction_log_lines)?
    else
      return ErrorState
    end

    // TODO: include orphaned list? doesn't makes sense if we aren't using S3 right now.

    AwaitMessageOr2PCPhase1State

  fun handle_deny_new_worker(ctx: StateContext, hello: cwm.HelloMsg val): SinkState =>
    let err = cwm.ErrorMsg("Hello message from worker " + hello.instance_name + ": already active")

    ctx.writev(err.encode().done())

    ctx.close()

    ErrorState

  fun handle_ok(ctx: StateContext, ok: cwm.OkMsg): SinkState =>
    ctx.queue_message(ok)
    this

  fun handle_error(ctx: StateContext, err: cwm.ErrorMsg): SinkState =>
    ctx.queue_message(err)
    this

  fun handle_notify(ctx: StateContext, notify: cwm.NotifyMsg): SinkState =>
    ctx.queue_message(notify)
    this

  fun handle_notify_ack(ctx: StateContext, notify_ack: cwm.NotifyAckMsg): SinkState =>
    ctx.queue_message(notify_ack)
    this

  fun handle_message(ctx: StateContext, message: cwm.MessageMsg): SinkState =>
    ctx.queue_message(message)
    this

  fun handle_eos(ctx: StateContext, eos: cwm.EosMessageMsg): SinkState =>
    ctx.queue_message(eos)
    this

  fun handle_ack(ctx: StateContext, ack: cwm.AckMsg): SinkState =>
    ctx.queue_message(ack)
    this

  fun handle_restart(ctx: StateContext, restart: cwm.RestartMsg): SinkState =>
    ctx.queue_message(restart)
    this

  fun handle_workers_left(ctx: StateContext, workers_left: cwm.WorkersLeftMsg): SinkState =>
    ctx.queue_message(workers_left)
    this

  fun string(): String iso^ => "AwaitApproveOrDenyWorkerState".clone()

primitive ErrorState is SinkState
  fun handle_hello(ctx: StateContext, hello: cwm.HelloMsg): SinkState => ErrorState
  fun handle_ok(ctx: StateContext, ok: cwm.OkMsg): SinkState => ErrorState
  fun handle_error(ctx: StateContext, err: cwm.ErrorMsg): SinkState => ErrorState
  fun handle_notify(ctx: StateContext, notify: cwm.NotifyMsg): SinkState => ErrorState
  fun handle_notify_ack(ctx: StateContext, notify_ack: cwm.NotifyAckMsg): SinkState => ErrorState
  fun handle_message(ctx: StateContext, message: cwm.MessageMsg): SinkState => ErrorState
  fun handle_eos(ctx: StateContext, eos: cwm.EosMessageMsg): SinkState => ErrorState
  fun handle_ack(ctx: StateContext, ack: cwm.AckMsg): SinkState => ErrorState
  fun handle_restart(ctx: StateContext, restart: cwm.RestartMsg): SinkState => ErrorState
  fun handle_workers_left(ctx: StateContext, workers_left: cwm.WorkersLeftMsg): SinkState => ErrorState

  fun string(): String iso^ =>
    "ErrorState".clone()

primitive AwaitMessageOr2PCPhase1State is SinkState
  fun handle_error(ctx: StateContext, err: cwm.ErrorMsg): SinkState =>
    HandleErrorMsg(ctx, err)
    ErrorState

  fun handle_notify(ctx: StateContext, notify: cwm.NotifyMsg): SinkState =>
    match HandleNotifyMsg(ctx, notify)
    | let ss: SinkState =>
      ss
    else
      AwaitMessageOr2PCPhase1State
    end

  fun handle_message(ctx: StateContext, message: cwm.MessageMsg): SinkState =>
    match message.stream_id
    | 0 =>
      let two_pc_bytes = MessageMessageToArray(message.message)

      try
        let two_pc_msg = cwm.TwoPCFrame.decode(two_pc_bytes)?

        match two_pc_msg
        | let m: cwm.ListUncommittedMsg =>
          HandleListUncommittedMsg(ctx, m)
          this
        | let m: cwm.TwoPCPhase1Msg =>
          Handle2PCPhase1Msg(ctx, m)
        else
          InvalidState
        end
      else
        Debug("error decoding 2PC message")
        AwaitMessageOr2PCPhase1State
      end
    else
      HandleMessageMsg(ctx, message)
      AwaitMessageOr2PCPhase1State
    end

  fun string(): String iso^ => "AwaitMessageOr2PCPhase1State".clone()

primitive AwaitMessageOr2PCPhase2State is SinkState
  fun handle_error(ctx: StateContext, err: cwm.ErrorMsg): SinkState =>
    HandleErrorMsg(ctx, err)
    ErrorState

  fun handle_notify(ctx: StateContext, notify: cwm.NotifyMsg): SinkState =>
    match HandleNotifyMsg(ctx, notify)
    | let ss: SinkState =>
      ss
    else
      AwaitMessageOr2PCPhase2State
    end

  fun handle_message(ctx: StateContext, message: cwm.MessageMsg): SinkState =>
    match message.stream_id
    | 0 =>
      let two_pc_bytes = MessageMessageToArray(message.message)

      try
        let two_pc_msg = cwm.TwoPCFrame.decode(two_pc_bytes)?

        match two_pc_msg
        | let m: cwm.ListUncommittedMsg =>
          HandleListUncommittedMsg(ctx, m)
          this
        | let m: cwm.TwoPCPhase2Msg =>
          Handle2PCPhase2Msg(ctx, m)
        else
          InvalidState
        end
        this
      else
        Debug("error decoding 2PC message")
        AwaitMessageOr2PCPhase2State
      end
    else
      HandleMessageMsg(ctx, message)
      AwaitMessageOr2PCPhase2State
    end

  fun string(): String iso^ => "AwaitMessageOr2PCPhase2State".clone()
