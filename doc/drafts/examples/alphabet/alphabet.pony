use "buffered"
use "collections"
use "sendence/bytes"
use "wallaroo/"
use "wallaroo/tcp-source"
use "wallaroo/topology"

actor Main
  new create(env: Env) =>
    try
      let letter_partition = Partition[Votes val, String](
        LetterPartitionFunction, PartitionFileReader("letters.txt",
          env.root as AmbientAuth))

      let application = recover val
        Application("Alphabet Popularity Contest")
          .new_pipeline[Votes val, LetterTotal val]("Alphabet Votes",
            VotesDecoder)
            .to_state_partition[Votes val, String, LetterTotal val,
              LetterState](AddVotes, LetterStateBuilder, "letter-state",
              letter_partition where multi_worker = true)
            .to_sink(LetterTotalEncoder, recover [0] end)
      end
      Startup(env, application, "alphabet-contest")
    else
      env.out.print("Couldn't build topology")
    end

class val LetterStateBuilder
  fun apply(): LetterState => LetterState
  fun name(): String => "Letter State"

class LetterState
  // TODO: Update state initialization so a state runner builder takes
  // a key on create so we can have one state actor per letter and each
  // knows its letter
  var letter: String = " "
  var count: U32 = 0

class AddVotesStateChange is StateChange[LetterState]
  var _id: U64
  var _votes: Votes val = Votes(" ", 0)

  new create(id': U64) =>
    _id = id'

  fun name(): String => "AddVotes"
  fun id(): U64 => _id

  fun ref update(votes': Votes val) =>
    _votes = votes'

  fun apply(state: LetterState ref) =>
    // TODO: This letter assignment will be unnecessary once we give a state
    // runner its corresponding key on startup since it will know its letter
    // initially
    state.letter = _votes.letter
    state.count = state.count + _votes.count

  fun write_log_entry(out_writer: Writer) =>
    out_writer.u32_be(_votes.letter.size().u32())
    out_writer.write(_votes.letter)
    out_writer.u32_be(_votes.count)

  fun ref read_log_entry(in_reader: Reader) ? =>
    let letter_size = in_reader.u32_be().usize()
    let letter = String.from_array(in_reader.block(letter_size))
    let count = in_reader.u32_be()
    _votes = Votes(letter, count)

class AddVotesStateChangeBuilder is StateChangeBuilder[LetterState]
  fun apply(id: U64): StateChange[LetterState] =>
    AddVotesStateChange(id)

primitive AddVotes is StateComputation[Votes val, LetterTotal val, LetterState]
  fun name(): String => "Add Votes"

  fun apply(votes: Votes val,
    sc_repo: StateChangeRepository[LetterState],
    state: LetterState): (LetterTotal val, StateChange[LetterState] ref)
  =>
    let state_change: AddVotesStateChange ref =
      try
        sc_repo.lookup_by_name("AddVotes") as AddVotesStateChange
      else
        AddVotesStateChange(0)
      end

    state_change.update(votes)

    // TODO: This is ugly since this is where we need to simulate the state
    // change in order to produce a result
    (LetterTotal(state.letter, state.count), state_change)

  fun state_change_builders():
    Array[StateChangeBuilder[LetterState] val] val
  =>
    recover val
      let scbs = Array[StateChangeBuilder[LetterState] val]
      scbs.push(recover val AddVotesStateChangeBuilder end)
    end

primitive VotesDecoder is FramedSourceHandler[Votes val]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    5

  fun decode(data: Array[U8] val): Votes val ? =>
    // Assumption: 1 byte for letter
    let letter = String.from_array(data.trim(0, 1))
    let count = Bytes.to_u32(data(1), data(2), data(3), data(4))
    Votes(letter, count)

primitive LetterPartitionFunction
  fun apply(votes: Votes val): String =>
    votes.letter

class Votes
  let letter: String
  let count: U32

  new val create(l: String, c: U32) =>
    letter = l
    count = c

class LetterTotal
  let letter: String
  let count: U32

  new val create(l: String, c: U32) =>
    letter = l
    count = c

// TODO: Remove need to call done() on Writer, and have no return type
primitive LetterTotalEncoder
  fun apply(t: LetterTotal val, wb: Writer = Writer): Array[ByteSeq] val =>
    wb.write(t.letter) // Assumption: letter is 1 byte
    wb.u32_be(t.count)
    wb.done()
