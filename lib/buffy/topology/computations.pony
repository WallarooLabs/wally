use "buffy/messages"
use "collections"

interface Computation[In, Out]
  fun ref apply(input: In): Out
  fun name(): String

interface MapComputation[In, Out]
  fun ref apply(input: In): Seq[Out]
  fun name(): String

interface FinalComputation[In]
  fun ref apply(input: In)

interface PartitionFunction[In]
  fun apply(input: In): U64

trait StateProcessor[State: Any #read]
  fun apply(state: State): State
  fun partition_id(): U64 => 0

interface StateComputation[Out: Any val, State: Any #read]
  fun apply(state: State, output: MessageTarget[Out] val): State

class StateComputationWrapper[In: Any val, Out: Any val, State: Any #read]
  is StateProcessor[State]
  let _state_computation: StateComputation[Out, State] val
  let _output: MessageTarget[Out] val
  let _partition_id: U64

  new val create(sc: StateComputation[Out, State] val,
    message_wrapper: MessageWrapper[Out] val,
    output_step: BasicStep tag, p_id: U64 = 0) =>
    _state_computation = sc
    _output = MessageTarget[Out](message_wrapper, output_step)
    _partition_id = p_id

  fun apply(state: State): State =>
    _state_computation(state, _output)

  fun partition_id(): U64 => _partition_id

class MessageTarget[Out: Any val]
  let _output: BasicStep tag
  let _message_wrapper: MessageWrapper[Out] val

  new val create(mw: MessageWrapper[Out] val, o: BasicStep tag) =>
    _output = o
    _message_wrapper = mw

  fun apply(data: Out) =>
    _output(_message_wrapper(data))

class MessageWrapper[T: Any val]
  let _id: U64
  let _source_ts: U64
  let _last_ingress_ts: U64

  new val create(id: U64, source_ts: U64, last_ingress_ts: U64) =>
    _id = id
    _source_ts = source_ts
    _last_ingress_ts = last_ingress_ts

  fun apply(data: T): Message[T] val =>
    Message[T](_id, _source_ts, _last_ingress_ts, data)

interface ComputationBuilder[In, Out]
  fun apply(): Computation[In, Out] iso^

interface MapComputationBuilder[In, Out]
  fun apply(): MapComputation[In, Out] iso^

interface StateComputationBuilder[In: Any val, Out: Any val,
  State: Any #read]
  fun apply(): StateComputation[Out, State] iso^

interface Parser[Out]
  fun apply(s: String): (Out | None) ?

interface Stringify[In]
  fun apply(i: In): String ?

class NoneStringify is Stringify[None]
  fun apply(i: None): String => ""
