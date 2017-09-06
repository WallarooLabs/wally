use "collections"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/core/topology"
use "wallaroo_labs/mort"

primitive StepStateMigrator
  fun receive_state(runner: Runner, state: ByteSeq val) =>
    ifdef "trace" then
      @printf[I32]("Received new state\n".cstring())
    end
    match runner
    | let r: SerializableStateRunner =>
      r.replace_serialized_state(state)
    else
      Fail()
    end

  fun send_state_to_neighbour(runner: Runner, neighbour: Step) =>
    match runner
    | let r: SerializableStateRunner =>
      neighbour.receive_state(r.serialize_state())
    else
      Fail()
    end

  fun send_state[K: (Hashable val & Equatable[K] val)](runner: Runner,
    id: StepId, boundary: OutgoingBoundary, state_name: String, key: K)
  =>
    match runner
    | let r: SerializableStateRunner =>
      let state: ByteSeq val = r.serialize_state()
      boundary.migrate_step[K](id, state_name, key, state)
    else
      Fail()
    end
