use "collections"
use "time"
use "sendence/bytes"
use "sendence/guid"
use "sendence/time"
use "wallaroo/boundary"
use "wallaroo/core"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/recovery"
use "wallaroo/fail"
use "wallaroo/routing"
use "wallaroo/source/tcp_source"
use "wallaroo/topology"

interface val WActorFramedSourceHandler
  fun header_length(): USize
  fun payload_length(data: Array[U8] iso): USize ?
  fun decode(data: Array[U8] val): Any val ?

class WActorSourceNotify is TCPSourceNotify
  let _guid_gen: GuidGenerator = GuidGenerator
  var _header: Bool = true
  let _source_name: String
  let _handler: WActorFramedSourceHandler
  var _helper: (WActorSourceHelper | None) = None
  let _actor_router: WActorRouter
  let _central_actor_registry: CentralWActorRegistry
  let _header_size: USize

  new iso create(auth: AmbientAuth,
    handler: WActorFramedSourceHandler, actor_router: WActorRouter,
    central_actor_registry: CentralWActorRegistry, event_log: EventLog)
  =>
    _source_name = "ActorSystem Source"
    _handler = handler
    _actor_router = actor_router
    _central_actor_registry = central_actor_registry
    _header_size = _handler.header_length()
    _helper = WActorSourceHelper(this)

  fun ref process_by_role(role: String, data: Any val) =>
    _central_actor_registry.process_by_role(role, data)

  fun ref broadcast_to_role(role: String, data: Any val) =>
    _central_actor_registry.broadcast_to_role(role, data)

  fun routes(): Array[Consumer] val =>
    recover Array[Consumer] end

  fun ref received(conn: TCPSource ref, data: Array[U8] iso): Bool =>
    if _header then
      try
        let payload_size: USize = _handler.payload_length(consume data)

        conn.expect(payload_size)
        _header = false
      end
      true
    else
      ifdef "trace" then
        @printf[I32](("Rcvd msg at " + _source_name + "\n").cstring())
      end

      try
        conn.next_sequence_id()
        let decoded =
          try
            _handler.decode(consume data)
          else
            ifdef debug then
              @printf[I32]("Error decoding message at source\n".cstring())
            end
            error
          end
        ifdef "trace" then
          @printf[I32](("Msg decoded at " + _source_name + "\n").cstring())
        end
        match _helper
        | let h: WActorSourceHelper =>
          _actor_router(decoded, h)
        else
          Fail()
        end
      else
        Fail()
      end

      conn.expect(_header_size)
      _header = true

      ifdef linux then
        true
      else
        false
      end
    end

  fun ref update_router(router: Router) =>
    None

  fun ref update_boundaries(obs: box->Map[String, OutgoingBoundary]) =>
    None

  fun ref accepted(conn: TCPSource ref) =>
    @printf[I32]((_source_name + ": accepted a connection\n").cstring())
    conn.expect(_header_size)

  // TODO: implement connect_failed

interface val WActorRouter
  fun apply(data: Any val, helper: WActorSourceHelper)

primitive SimulationFramedSourceHandler
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

  fun decode(data: Array[U8] val): Any val =>
    Act

primitive IngressWActorRouter
  fun apply(data: Any val, helper: WActorSourceHelper) =>
    helper.broadcast_to_role(BasicRoles.ingress(), data)

class WActorSourceHelper
  let _notify: WActorSourceNotify

  new create(notify: WActorSourceNotify) =>
    _notify = notify

  fun ref send_to_role(role: String, data: Any val) =>
    _notify.process_by_role(role, data)

  fun ref broadcast_to_role(role: String, data: Any val) =>
    _notify.broadcast_to_role(role, data)
