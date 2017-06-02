use "assert"
use "buffered"
use "collections"
use pers = "collections/persistent"
use "net"
use "random"
use "time"
use "sendence/bytes"
use "sendence/fix"
use "sendence/guid"
use "sendence/hub"
use "sendence/new_fix"
use "sendence/options"
use "sendence/rand"
use "sendence/time"
use "wallaroo"
use "wallaroo/fail"
use "wallaroo/metrics"
use "wallaroo/tcp_source"
use "wallaroo/topology"
use "wallaroo/w_actor"


primitive Roles
  fun counter(): String => "counter"
  fun accumulator(): String => "accumulator"

actor Main
  new create(env: Env) =>
    let seed: U64 = 12345
    let actor_count: USize = 10
    let iterations: USize = 100
    let actor_system = create_actors(actor_count, iterations, seed)
    ActorSystemStartup(env, actor_system, "toy-model-CRDT-app", actor_count)

  fun ref create_actors(n: USize, iterations: USize, init_seed: U64):
    ActorSystem val
  =>
    recover
      let rand = EnhancedRandom(init_seed)
      let actor_system =
        ActorSystem("Toy Model CRDT App", rand.u64())
          .> add_source(SimulationFramedSourceHandler, IngressWActorRouter)
          .> add_actor(ABuilder(Roles.accumulator(), rand.u64()))

      for i in Range(0, n - 1) do
        let next_seed = rand.u64()
        let next = ABuilder(Roles.counter(), next_seed)
        actor_system.add_actor(next)
      end
      actor_system
    end

class GCounter
  let id: U64
  var data: PMap[U64, USize]

  new create(id': U64) =>
    id = id'
    data = PMap[U64, USize]

  fun ref increment() =>
    try
      let current = data(id)
      data = data.update(id, 1 + current)
    else
      data = data.update(id, 1)
    end

  fun ref merge(other: PMap[U64, USize]) =>
    for (k, v) in other.map().pairs() do
      try
        let local = data(k)
        let new_value = local.max(v)
        data = data.update(k, new_value)
      else
        data = data.update(k, v)
      end
    end

  fun value(): USize =>
    var total: USize = 0
    for (k, v) in data.map().pairs() do
      total = total + v
    end
    total

  fun ref string(): String => "GCounter(" + value().string() + ")"

class A is WActor
  var _round: USize = 0
  let _id: U64
  let _role: String
  var _pending_increments: USize = 0
  let _g_counter: GCounter
  let _rand: EnhancedRandom
  var _waiting: USize = 0
  var _started: Bool = false

  new create(h: WActorHelper, role': String, id': U64, seed: U64) =>
    _role = role'
    h.register_as_role(_role)
    h.register_as_role(BasicRoles.ingress())
    _id = id'
    _g_counter = GCounter(_id)
    _rand = EnhancedRandom(seed)

  fun ref receive(sender: U128, payload: Any val, h: WActorHelper) =>
    match payload
    | ActMsg =>
      act(h)
    | let m: IncrementsMsg =>
      _pending_increments = _pending_increments + m.count
    | let m: GossipMsg =>
      _g_counter.merge(m.data)
    | let m: FinishMsg =>
      for i in Range(0, _pending_increments) do
        _g_counter.increment()
      end
      if _role == Roles.counter() then
        h.send_to_role(Roles.accumulator(),
          FinishGossipMsg(_g_counter.data))
      end
    | let m: FinishGossipMsg =>
      _g_counter.merge(m.data)
      @printf[I32]("Finishing: %s\n".cstring(),
        _g_counter.string().cstring())
    else
      @printf[I32]("Unknown message type received at w_actor\n".cstring())
    end

  fun ref process(data: Any val, h: WActorHelper) =>
    match data
    | Act =>
      act(h)
      if _role == Roles.accumulator() then
        @printf[I32]("Accumulator Act report: %s\n".cstring(),
          _g_counter.string().cstring())
      end
    end

  fun ref act(h: WActorHelper) =>
    if _role == Roles.accumulator() then
      @printf[I32]("Round %lu: %s\n".cstring(),
        _round, _g_counter.string().cstring())
    else
      for i in Range(0, _pending_increments) do
        _g_counter.increment()
      end
      _pending_increments = 0
      emit_messages(h)
    end

    _round = _round + 1

  fun ref emit_messages(h: WActorHelper) =>
    let inc_msg_count = _rand.usize_between(1, 4)
    _waiting = _waiting + inc_msg_count
    for i in Range(0, inc_msg_count) do
      let msg = IncrementsMsg(_rand.usize_between(1, 3))
      h.send_to_role(Roles.counter(), msg)
    end

    let gossip_msg_count = _rand.usize_between(1, 4)
    let gossip_msg = GossipMsg(_g_counter.data)
    for i in Range(0, gossip_msg_count) do
      h.send_to_role(Roles.counter(), gossip_msg)
    end
    h.send_to_role(Roles.accumulator(), gossip_msg)

trait AMsg

trait AMsgBuilder

primitive IncrementsMsgBuilder is AMsgBuilder
  fun apply(increments: USize): IncrementsMsg val =>
    IncrementsMsg(increments)

primitive GossipMsgBuilder is AMsgBuilder
  fun apply(data: PMap[U64, USize]): GossipMsg val =>
    GossipMsg(data)

class val IncrementsMsg is AMsg
  let count: USize
  new val create(c: USize) => count = c

primitive ActMsg is AMsg
primitive FinishMsg is AMsg

class val GossipMsg is AMsg
  let data: PMap[U64, USize]
  new val create(d: PMap[U64, USize]) => data = d

class val FinishGossipMsg is AMsg
  let data: PMap[U64, USize]
  new val create(d: PMap[U64, USize]) => data = d

class ABuilder
  let _role: String
  let _seed: U64

  new val create(role: String = "", seed: U64) =>
    _role = role
    _seed = seed

  fun apply(id: U128, wh: WActorHelper): WActor =>
    let short_id = (id >> 96).u64()
    A(wh, _role, short_id, _seed)

class val PMap[K: (Hashable val & Equatable[K] val), V: Any val]
  let _s: Map[K, V] val

  new val create(s: Map[K, V] val = recover Map[K, V] end) =>
    _s = s

  fun size(): USize => _s.size()

  fun apply(k: K): V ? => _s(k)

  fun val update(k: K, v: V): PMap[K, V] =>
    let m: Map[K, V] trn = recover Map[K, V] end
    for (k', v') in _s.pairs() do
      m(k') = v'
    end
    m(k) = v
    PMap[K, V](consume m)

  fun map(): Map[K, V] val => _s
