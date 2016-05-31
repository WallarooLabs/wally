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

interface StateComputation[In,
  Out: Any val, State: Any iso]
  fun apply(state: State, default_output_step: BasicStep tag,
    message_wrapper: MessageWrapper[Out] val)

interface MessageWrapper[T: Any val]
  fun apply(data: T): Message[T] val

class DefaultMessageWrapper[T: Any val] is MessageWrapper[T]
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

interface StateComputationBuilder[In, Out: Any val,
  State: Any iso]
  fun apply(): StateComputation[In, Out, State] iso^

interface Parser[Out]
  fun apply(s: String): Out ?

interface Stringify[In]
  fun apply(i: In): String ?

class NoneStringify is Stringify[None]
  fun apply(i: None): String => ""
