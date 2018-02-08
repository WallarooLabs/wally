/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "wallaroo_labs/mort"

primitive PartitionRebalancer
  fun step_counts_to_send(total_steps: USize, worker_portion: USize,
    current_workers_count: USize, joining_worker_count: USize):
    (USize, Array[USize] val)
  =>
    """
    Calculate how many steps a worker should send based on the total steps
    in the partition, the portion of those steps on the sending worker,
    the current count of workers, and the number of joining workers.

    The aim of this algorithm is to have a roughly equal number of steps on
    each worker.  Returns the total amount to send and a list of how many
    to send to each worker.
    """
    // Ideal # of steps per worker before sending
    let ideal_pre: F64 = total_steps.f64() / current_workers_count.f64()
    // Ideal # of steps per worker after sending
    let ideal_post: F64 =
      total_steps.f64() / (current_workers_count + joining_worker_count).f64()
    // How far this worker is off from the ideal before sending
    let off_by = worker_portion.f64() - ideal_pre

    // Adjust for how far off from the ideal we are. This means we don't
    // need to coordinate across workers. Each can converge to the correct
    // overall value independently.
    let try_to_send =
      if off_by > 1 then
        let adjusted = ideal_post + (off_by - 1)
        worker_portion - adjusted.round().usize()
      elseif off_by < -1 then
        let adjusted = ideal_post + (off_by - 1)
        worker_portion - adjusted.round().usize()
      else
        worker_portion - ideal_post.round().usize()
      end

    let counts_to_send = recover trn Array[USize] end
    // Never send your last step.
    if (worker_portion - try_to_send) > 0 then
      let common_amount = try_to_send / joining_worker_count
      var leftover = try_to_send - (common_amount * joining_worker_count)
      for i in Range(0, joining_worker_count) do
        let next_count_to_send =
          if leftover > 0 then
            leftover = leftover - 1
            common_amount + 1
          else
            common_amount
          end
        counts_to_send.push(next_count_to_send)
      end
    else
      for i in Range(0, joining_worker_count) do
        counts_to_send.push(0)
      end
    end

    var total_to_send: USize = 0
    for c in counts_to_send.values() do
      total_to_send = total_to_send + c
    end

    (total_to_send, consume counts_to_send)

  fun step_counts_to_send_on_leaving(total_steps: USize,
    remaining_workers_count: USize): Array[USize] val
  =>
    var remaining_steps = total_steps
    let counts = recover trn Array[USize] end
    for i in Range(0, remaining_workers_count) do
      counts.push(0)
    end
    var idx: USize = 0
    while remaining_steps > 0 do
      try
        counts(idx)? = counts(idx)? + 1
      else
        Fail()
      end
      remaining_steps = remaining_steps - 1
      idx = (idx + 1) % remaining_workers_count
    end
    consume counts
