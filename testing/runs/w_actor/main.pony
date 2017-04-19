use "assert"
use "buffered"
use "collections"
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


actor Main
  new create(env: Env) =>
    let seed: U64 = 123456
    let actor_count: USize = 10
    try
      let actor_system = create_actors(actor_count, seed)
      ActorSystemStartup(env, actor_system, "Toy Model App")
    else
      Fail()
    end

  fun ref create_actors(n: USize, init_seed: U64): ActorSystem val ? =>
    recover
      let roles: Array[String] val = recover [ARoles.one(), ARoles.two(),
        ARoles.three()] end
      let rand = Rand(init_seed)
      if n < 3 then
        @printf[I32]("There must be at least 3 actors\n".cstring())
        Fail()
      end
      let actor_system = ActorSystem("Toy Model", rand.u64())
      actor_system.add_actor(ABuilder(ARoles.one(), Time.micros()))
      actor_system.add_actor(ABuilder(ARoles.two(), Time.micros()))
      actor_system.add_actor(ABuilder(ARoles.three(), Time.micros()))
      for i in Range(0, n - 3) do
        let role = rand.pick[String](roles)
        let next_seed = rand.u64()
        let next = ABuilder(role, next_seed)
        actor_system.add_actor(next)
      end
      actor_system
    end

primitive ARoles
  fun one(): String => "one"
  fun two(): String => "two"
  fun three(): String => "three"

trait AMsg
  fun string(): String

trait AMsgBuilder

primitive SetActorProbability is AMsgBuilder
  fun apply(prob: F64): SetActorProbabilityMsg val =>
    SetActorProbabilityMsg(prob)

primitive SetNumberOfMessagesToSend is AMsgBuilder
  fun apply(n: USize): SetNumberOfMessagesToSendMsg val =>
    SetNumberOfMessagesToSendMsg(n)

primitive ChangeMessageTypesToSend is AMsgBuilder
  fun apply(types: Array[AMsgBuilder val] val):
    ChangeMessageTypesToSendMsg val
  =>
    ChangeMessageTypesToSendMsg(types)

class SetActorProbabilityMsg is AMsg
  let prob: F64

  new val create(prob': F64) =>
    prob = prob'

  fun string(): String => "SetActorProbabilityMsg"

class SetNumberOfMessagesToSendMsg is AMsg
  let n: USize

  new val create(n': USize) =>
    n = n'

  fun string(): String => "SetNumberOfMessagesToSendMsg"

class ChangeMessageTypesToSendMsg is AMsg
  let types: Array[AMsgBuilder val] val

  new val create(types': Array[AMsgBuilder val] val) =>
    types = types'

  fun string(): String => "ChangeMessageTypesToSendMsg"

class A is WActor
  let _id: U64
  let _helper: WActorHelper
  var _emission_prob: F64 = 0.5
  var _n_messages: USize = 1
  let _all_message_types: Array[AMsgBuilder val] val
  var _message_types_to_send: Array[AMsgBuilder val] val
  let _rand: Rand

  new create(wh: WActorHelper, role: String, id: U128, seed: U64) =>
    _id = (id >> 96).u64()
    _helper = wh
    if role != "" then
      _helper.register_as_role(role)
    end
    _all_message_types =
      try
        let ts: Array[AMsgBuilder val] trn = recover Array[AMsgBuilder val] end
        ts.push(SetActorProbability as AMsgBuilder val)
        ts.push(SetNumberOfMessagesToSend as AMsgBuilder val)
        ts.push(ChangeMessageTypesToSend as AMsgBuilder val)
        consume ts
      else
        recover Array[AMsgBuilder val] end
      end
    _message_types_to_send = _all_message_types
    _rand = Rand(seed)

  fun ref receive(sender: WActorId, payload: Any val) =>
    match payload
    | let m: SetActorProbabilityMsg val =>
      ifdef debug then
        @printf[I32]("Received %s to %s\n".cstring(), m.string().cstring(),
          m.prob.string().cstring())
      end
      _emission_prob = m.prob
    | let m: SetNumberOfMessagesToSendMsg val =>
      // @printf[I32]("Received %s to %lu msgs\n".cstring(),
        // m.string().cstring(), m.n)
      _n_messages = m.n
    | let m: ChangeMessageTypesToSendMsg val =>
      ifdef debug then
        @printf[I32]("Received %s\n".cstring(), m.string().cstring())
      end
      _message_types_to_send = m.types
    else
      @printf[I32]("Unknown message type received at w_actor\n".cstring())
    end

  fun ref process(data: Any val) =>
    match data
    | let a: Act val =>
      try
        emit_messages()
      else
        Fail()
      end
    end

  fun ref emit_messages() ? =>
    let known_actors = _helper.known_actors()
    for i in Range(1, _n_messages + 1) do
      let should_emit = (known_actors.size() > 0) and
        (_rand.test_odds(_emission_prob))
      if should_emit then
        let message = create_message()
        let target = select_actor()
        _helper.send_to(target, message)
        ifdef debug then
          @printf[I32]("Actor %lu emitted a message on iteration %d out of %d. Message is of type %s.\n".cstring(), _id, i, _n_messages,
            message.string().cstring())
        end
      else
        ifdef debug then
          @printf[I32]("Actor %lu did not emit any message on iteration %d out of %d\n".cstring(), _id, i, _n_messages)
        end
      end
    end

  fun ref select_actor(): WActorId ? =>
    _rand.pick[WActorId](_helper.known_actors())

  fun ref create_message(): AMsg val ? =>
    match _rand.pick[AMsgBuilder val](_message_types_to_send)
    | let blder: SetActorProbability val =>
      SetActorProbability(_rand.f64_between(0.1, 0.9))
    | let blder: SetNumberOfMessagesToSend val =>
      SetNumberOfMessagesToSend(_rand.usize_between(1, 4))
    | let blder: ChangeMessageTypesToSend val =>
      let types = _rand.pick_subset[AMsgBuilder val](
        _all_message_types)
      ChangeMessageTypesToSend(types)
    else
      @printf[I32]("Had no message types to create! Sending SetActorProbability\n".cstring())
      SetActorProbability(0.5)
    end

class ABuilder
  let _role: String
  let _seed: U64

  new val create(role: String = "", seed: U64) =>
    _role = role
    _seed = seed

  fun apply(id: U128, wh: WActorHelper): WActor =>
    A(wh, _role, id, _seed)
