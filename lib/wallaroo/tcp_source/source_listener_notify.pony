use "wallaroo/fail"
use "wallaroo/recovery"
use "wallaroo/source"
use "wallaroo/topology"

class SourceListenerNotify is TCPSourceListenerNotify
  var _source_builder: SourceBuilder
  let _event_log: EventLog
  let _target_router: Router
  let _auth: AmbientAuth

  new iso create(builder: SourceBuilder, event_log: EventLog, auth: AmbientAuth,
    target_router: Router) =>
    _source_builder = builder
    _event_log = event_log
    _target_router = target_router
    _auth = auth

  fun ref listening(listen: TCPSourceListener ref) =>
    @printf[I32]((_source_builder.name() + " source is listening\n").cstring())

  fun ref not_listening(listen: TCPSourceListener ref) =>
    @printf[I32](
      (_source_builder.name() + " source is unable to listen\n").cstring())
    Fail()

  fun ref connected(listen: TCPSourceListener ref): TCPSourceNotify iso^ ? =>
    try
      _source_builder(_event_log, _auth, _target_router) as TCPSourceNotify iso^
    else
      @printf[I32](
        (_source_builder.name() + " could not create a TCPSourceNotify\n").cstring())
      Fail()
      error
    end

  fun ref update_router(router: Router) =>
    _source_builder = _source_builder.update_router(router)
