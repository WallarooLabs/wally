use "collections"
use "debug"
use "net"

use cwm = "wallaroo_labs/connector_wire_messages"

trait tag SinkStateMachine
  be apply(msg: cwm.Message iso)
  be approve_new_worker(hello: cwm.HelloMsg val, streams: Map[cwm.StreamId, (cwm.StreamId, cwm.StreamName, cwm.PointOfRef)] val)
  be deny_new_worker(hello: cwm.HelloMsg val)

actor UnconnectedSinkStateMachine is SinkStateMachine
  be apply(msg: cwm.Message iso) =>
    None
  be approve_new_worker(hello: cwm.HelloMsg val, streams: Map[cwm.StreamId, (cwm.StreamId, cwm.StreamName, cwm.PointOfRef)] val) =>
    None
  be deny_new_worker(hello: cwm.HelloMsg val) =>
    None

actor ConnectedSinkStateMachine is SinkStateMachine
  let _ctx: StateContext
  var _state: SinkState

  new create(conn: TCPConnection, active_workers: ActiveWorkers, initial_state: SinkState) =>
    _ctx = StateContext(this, conn, active_workers)
    _state = initial_state

  be approve_new_worker(hello: cwm.HelloMsg val, streams: Map[cwm.StreamId, (cwm.StreamId, cwm.StreamName, cwm.PointOfRef)] val) =>
    _state = _state.handle_approve_new_worker(_ctx, hello, streams)

    for m in _ctx.get_queued_messages_values() do
      _apply(m)
    end

    _ctx.clear_queued_messages()

  be deny_new_worker(hello: cwm.HelloMsg val) =>
    _state = _state.handle_deny_new_worker(_ctx, hello)

  be apply(msg_iso: cwm.Message iso) =>
    _apply(consume msg_iso)

  fun ref _apply(msg: cwm.Message) =>
    let old_state = _state
    _state = match msg
    | let msg': cwm.HelloMsg =>
      _state.handle_hello(_ctx, msg')
    | let msg': cwm.OkMsg =>
      _state.handle_ok(_ctx, msg')
    | let msg': cwm.ErrorMsg =>
      _state.handle_error(_ctx, msg')
    | let msg': cwm.NotifyMsg =>
      _state.handle_notify(_ctx, msg')
    | let msg': cwm.NotifyAckMsg =>
      _state.handle_notify_ack(_ctx, msg')
    | let msg': cwm.MessageMsg =>
      _state.handle_message(_ctx, msg')
    | let msg': cwm.EosMessageMsg =>
      _state.handle_eos(_ctx, msg')
    | let msg': cwm.AckMsg =>
      _state.handle_ack(_ctx, msg')
    | let msg': cwm.RestartMsg =>
      _state.handle_restart(_ctx, msg')
    | let msg': cwm.WorkersLeftMsg =>
      _state.handle_workers_left(_ctx, msg')
    end

    ifdef debug then
      let msg_type = match msg
      | let msg': cwm.HelloMsg => "HELLO"
      | let msg': cwm.OkMsg => "OK"
      | let msg': cwm.ErrorMsg => "ERROR"
      | let msg': cwm.NotifyMsg => "NOTIFY"
      | let msg': cwm.NotifyAckMsg => "NOTIFY_ACK"
      | let msg': cwm.MessageMsg => "MESSAGE"
      | let msg': cwm.EosMessageMsg => "EOS"
      | let msg': cwm.AckMsg => "ACK"
      | let msg': cwm.RestartMsg => "RESTART"
      | let msg': cwm.WorkersLeftMsg => "WORKERS_LEFT"
      end

      Debug(" ".join([old_state; " X "; msg_type; " => "; _state].values()))
    end
