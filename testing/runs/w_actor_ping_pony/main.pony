use "assert"
use "buffered"
use "collections"
use "debug"
use "net"
use "options"
use "random"
use "time"
use "sendence/bytes"
use "sendence/fix"
use "sendence/guid"
use "sendence/hub"
use "sendence/new_fix"
use "sendence/rand"
use "wallaroo"
use "wallaroo/ent/w_actor"
use "wallaroo/fail"
use "wallaroo/metrics"
use "wallaroo/source/tcp_source"
use "wallaroo/topology"

primitive Roles
  fun ping(): String => "ping"
  fun pong(): String => "pong"

actor Main
  new create(env: Env) =>
    let seed: U64 = 54321
    let actor_count: USize = 2
    let actor_system = create_actors(actor_count, seed)
    ActorSystemStartup(env, actor_system, "ping-pong-app", actor_count)

  fun ref create_actors(n: USize, init_seed: U64): ActorSystem val =>
    recover
      let rand = Rand(init_seed)
      let actor_system = ActorSystem("Ping Pong App", rand.u64())
      actor_system.add_actor(PingBuilder(Roles.ping()))
      actor_system.add_actor(PongBuilder(Roles.pong()))
      actor_system
    end

class Ping is WActor
  let _id: U64
  let _role: String
  var _started: Bool = false

  new create(h: WActorHelper, role: String, id: U64) =>
    _role = role
    _id = id
    h.register_as_role(_role)

  fun ref receive(sender: U128, payload: Any val, h: WActorHelper) =>
    match payload
    | let hit: Hit =>
      @printf[I32]("Ping: hit\n".cstring())
      // Debug("Ping: hit")
      h.send_to_role(Roles.pong(), Hit)
    else
      @printf[I32]("Unknown message type received at w_actor\n".cstring())
    end

  fun ref process(data: Any val, h: WActorHelper) =>
    match data
    | Act =>
      if not _started then
        _started = true
        h.send_to_role(Roles.pong(), Hit)
        @printf[I32]("Ping: starting!\n".cstring())
      end
    end

class Pong is WActor
  let _id: U64
  let _role: String

  new create(h: WActorHelper, role: String, id: U64) =>
    _role = role
    _id = id
    h.register_as_role(_role)

  fun ref receive(sender: U128, payload: Any val, h: WActorHelper) =>
    match payload
    | let hit: Hit =>
      @printf[I32]("Pong: hit\n".cstring())
      // Debug("Pong: hit")
      h.send_to_role(Roles.ping(), Hit)
    else
      @printf[I32]("Unknown message type received at w_actor\n".cstring())
    end

  fun ref process(data: Any val, h: WActorHelper) =>
    match data
    | Act =>
      @printf[I32]("Pong: act!\n".cstring())
    end

primitive Hit

class PingBuilder
  let _role: String

  new val create(role: String) =>
    _role = role

  fun apply(id: U128, wh: WActorHelper): WActor =>
    let short_id = (id >> 96).u64()
    Ping(wh, _role, short_id)

class PongBuilder
  let _role: String

  new val create(role: String) =>
    _role = role

  fun apply(id: U128, wh: WActorHelper): WActor =>
    let short_id = (id >> 96).u64()
    Pong(wh, _role, short_id)
