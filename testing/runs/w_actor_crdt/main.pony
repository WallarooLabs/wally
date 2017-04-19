use "assert"
use "buffered"
use "collections"
use pers = "collections/persistent"
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
use "sendence/wall_clock"
use "wallaroo"
use "wallaroo/fail"
use "wallaroo/metrics"
use "wallaroo/tcp_source"
use "wallaroo/topology"
use "wallaroo/w_actor"


primitive Roles
  fun counter(): String => "counter"
  fun accumulator(): String => "accumulator"
  fun sync(): String => "sync"

actor Main
  new create(env: Env) =>
    let seed: U64 = 12345
    let actor_count: USize = 10
    let iterations: USize = 100
    let actor_system = create_actors(actor_count, iterations, seed)
    ActorSystemStartup(env, actor_system, "Toy Model CRDT App")

  fun ref create_actors(n: USize, iterations: USize, init_seed: U64):
    ActorSystem val
  =>
    recover
      let rand = Rand(init_seed)
      let actor_system = ActorSystem("Toy Model CRDT App", rand.u64())
      actor_system.add_actor(ABuilder(Roles.accumulator(),
        rand.u64()))
      actor_system.add_actor(SyncBuilder(iterations, n - 2))
      for i in Range(0, n - 2) do
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
  let _helper: WActorHelper
  var _round: USize = 0
  let _id: U64
  let _role: String
  var _pending_increments: USize = 0
  let _g_counter: GCounter
  let _rand: Rand
  var _waiting: USize = 0
  var _started: Bool = false

  new create(wh: WActorHelper, role': String, id': U64, seed: U64) =>
    _helper = wh
    _role = role'
    _helper.register_as_role(_role)
    _id = id'
    _g_counter = GCounter(_id)
    _rand = Rand(seed)

  fun ref receive(sender: WActorId, payload: Any val) =>
    match payload
    | ActMsg =>
      act()
    | let m: IncrementsMsg =>
      _pending_increments = _pending_increments + m.count
      _helper.send_to(sender, AckMsg)
    | let m: GossipMsg =>
      _g_counter.merge(m.data)
    | let ack: AckMsg =>
      _waiting = _waiting - 1
      if (_waiting == 0) then
        _helper.send_to_role(Roles.sync(), AckMsg)
      end
    | let m: FinishMsg =>
      for i in Range(0, _pending_increments) do
        _g_counter.increment()
      end
      if _role == Roles.counter() then
        _helper.send_to_role(Roles.accumulator(),
          FinishGossipMsg(_g_counter.data))
      end
    | let m: FinishGossipMsg =>
      _g_counter.merge(m.data)
      @printf[I32]("Finishing: %s\n".cstring(),
        _g_counter.string().cstring())
    else
      @printf[I32]("Unknown message type received at w_actor\n".cstring())
    end

  fun ref process(data: Any val) =>
    match data
    | Act =>
      if not _started then
        _helper.send_to_role(Roles.sync(), AckMsg)
        _started = true
      end
    end

  fun ref act() =>
    if _role == Roles.accumulator() then
      @printf[I32]("Round %lu: %s\n".cstring(),
        _round, _g_counter.string().cstring())
    end
    _round = _round + 1
    // @printf[I32]("%lu: Incrementing %lu\n".cstring(), _id, _pending_increments)
    for i in Range(0, _pending_increments) do
      _g_counter.increment()
    end
    _pending_increments = 0
    emit_messages()

  fun ref emit_messages() =>
    let inc_msg_count = _rand.usize_between(1, 4)
    _waiting = _waiting + inc_msg_count
    for i in Range(0, inc_msg_count) do
      let msg = IncrementsMsg(_rand.usize_between(1, 3))
      _helper.send_to_role(Roles.counter(), msg)
    end

    let gossip_msg_count = _rand.usize_between(1, 4)
    let gossip_msg = GossipMsg(_g_counter.data)
    for i in Range(0, gossip_msg_count) do
      _helper.send_to_role(Roles.counter(), gossip_msg)
    end
    _helper.send_to_role(Roles.accumulator(), gossip_msg)

class Sync is WActor
  let _helper: WActorHelper
  let _actor_count: USize
  var _iterations: USize = 0
  let _expected_iterations: USize
  var _acked: USize = 0
  let _actors: SetIs[WActorId] = _actors.create()

  new create(h: WActorHelper, actor_count': USize,
    expected_iterations': USize)
  =>
    _helper = h
    _helper.register_as_role(Roles.sync())
    _actor_count = actor_count'
    _expected_iterations = expected_iterations'

  fun ref receive(sender: WActorId, payload: Any val) =>
    _actors.set(sender)
    match payload
    | AckMsg =>
      _acked = _acked + 1
      if (_acked == _actor_count) then
        if _iterations < _expected_iterations then
          for a in _actors.values() do
            _helper.send_to(a, ActMsg)
          end
          _acked = 0
          _iterations = _iterations + 1
        elseif _iterations == _expected_iterations then
          for a in _actors.values() do
            _helper.send_to(a, FinishMsg)
          end
          _acked = 0
          _iterations = _iterations + 1
        end
      end
    end

  fun ref process(data: Any val) =>
    None

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

primitive AckMsg is AMsg
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

class SyncBuilder
  let _iterations: USize
  let _actor_count: USize

  new val create(iterations: USize, actor_count: USize) =>
    _iterations = iterations
    _actor_count = actor_count

  fun apply(id: U128, wh: WActorHelper): WActor =>
    Sync(wh, _actor_count, _iterations)

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
