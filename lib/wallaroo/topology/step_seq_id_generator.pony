use "wallaroo/core"
use "wallaroo/routing"

class ref StepSeqIdGenerator
  """
  Generate a new sequence id based on what has happened so far in the step.

  **`new_incoming_message` must be called at the start of handling each
  incoming message**

  `new_id` always generates the next id in the sequence.

  `latest_for_run` will generate a new id if we haven't yet generated one when
  handling the current message (as denoted by calling `new_incoming_message`).
  If we have already generated a message, then `latest_for_run` will return the
  most recently generated sequence id.
  """
  var _generate_new: Bool = true
  // 0 is reserved for "not seen yet"
  var _seq_id: SeqId

  new create(initial_seq_id: SeqId = 0) =>
    _seq_id = initial_seq_id

  fun ref latest_for_run(): SeqId =>
    """
    Gets the most recent id for a given step run.

    If no id, has been generated yet, then we want to generate a
    new one, otherwise, use the most recent for this run.
    """
    if _generate_new then
      new_id()
    else
      _seq_id
    end

  fun ref new_id(): SeqId =>
    """
    Generate a new id
    """
    _generate_new = false
    _seq_id = _seq_id + 1
    _seq_id

  fun ref new_incoming_message() =>
    """
    Needs to be called at the beginning of a run on a step to set up correct
    `latest_for_run` usage.
    """
    _generate_new = true

  fun last_id(): SeqId =>
    _seq_id
