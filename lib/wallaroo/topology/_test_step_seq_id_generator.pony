use "sendence/connemara"
use "wallaroo/routing"

actor _TestStepSeqIdGenerator is TestList
  new make() =>
    None

  fun tag tests(test: Connemara) =>
    test(_TestLatestAfterNew)
    test(_TestLatestWithoutNew)

class iso _TestLatestAfterNew is UnitTest
  """
  Verify calling `latest_for_run` after `new_id` results in the same id.
  """
  fun name(): String =>
    "step_seq_id_generator/latest_after_new"

  fun ref apply(h: TestHelper) =>
    let gen = StepSeqIdGenerator

    gen.new_incoming_message()
    let x = gen.new_id()
    let y = gen.latest_for_run()

    h.assert_ne[SeqId](0, x)
    h.assert_eq[SeqId](x, y)

class iso _TestLatestWithoutNew is UnitTest
  """
  Verify calling `latest_for_run` returns a new id when not used in conjunction
  with a call to new. We do this by doing more than one "run" and verify that
  the ids are different.
  """
  fun name(): String =>
    "step_seq_id_generator/latest_without_new"

  fun ref apply(h: TestHelper) =>
    let gen = StepSeqIdGenerator

    gen.new_incoming_message()
    let x = gen.latest_for_run()
    gen.new_incoming_message()
    let y = gen.latest_for_run()

    h.assert_ne[SeqId](0, x)
    h.assert_eq[SeqId](1, y - x)
