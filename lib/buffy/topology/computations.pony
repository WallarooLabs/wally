use "buffy/messages"
use "buffy/topology/external"
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
  fun apply(msg_id: U64, source_ts: U64, ingress_ts: U64, state: State): State
  fun partition_id(): U64 => 0

interface StateComputation[Out: Any val, State: Any #read]
  fun apply(state: State, output: MessageTarget[Out] val): State

class StateComputationWrapper[In: Any val, Out: Any val, State: Any #read]
  is StateProcessor[State]
  let _state_computation: StateComputation[Out, State] val
  let _output: BasicStep tag
  let _partition_id: U64

  new val create(sc: StateComputation[Out, State] val,
    output_step: BasicStep tag, p_id: U64 = 0) =>
    _state_computation = sc
    _output = output_step
    _partition_id = p_id

  fun apply(msg_id: U64, source_ts: U64, ingress_ts: U64, state: State): State 
  =>
    let target = MessageTarget[Out](_output, msg_id, source_ts, ingress_ts)
    _state_computation(state, target)

  fun partition_id(): U64 => _partition_id

class MessageTarget[Out: Any val]
  let _output: BasicStep tag
  let _id: U64
  let _source_ts: U64
  let _ingress_ts: U64

  new val create(o: BasicStep tag, msg_id: U64, source_ts: U64, 
    ingress_ts: U64) =>
    _output = o
    _id = msg_id
    _source_ts = source_ts
    _ingress_ts = ingress_ts

  fun apply(data: Any val) =>
    match data
    | let o: Out =>
      _output.send[Out](_id, _source_ts, _ingress_ts, o)
    end

interface ComputationBuilder[In, Out]
  fun apply(): Computation[In, Out] iso^

interface MapComputationBuilder[In, Out]
  fun apply(): MapComputation[In, Out] iso^

interface StateComputationBuilder[In: Any val, Out: Any val,
  State: Any #read]
  fun apply(): StateComputation[Out, State] iso^

trait ExternalProcessBuilder[In: Any val, Out: Any val]
  fun config(): ExternalProcessConfig val
  fun codec(): ExternalProcessCodec[In, Out] val
  fun length_encoder(): ByteLengthEncoder val
  fun name(): String val

interface Parser[Out]
  fun apply(s: String): (Out | None) ?

interface Stringify[In]
  fun apply(i: In): String ?

interface ArrayStringify[In]
  fun apply(i: In): (String | Array[String] val) ?

class NoneStringify is Stringify[None]
  fun apply(i: None): String => ""
