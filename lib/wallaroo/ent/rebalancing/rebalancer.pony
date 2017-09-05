/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

primitive PartitionRebalancer
  fun step_count_to_send(total_steps: USize, worker_portion: USize,
    current_workers_count: USize): USize
  =>
    """
    Calculate how many steps a worker should send based on the total steps
    in the partition, the portion of those steps on the sending worker,
    and the current count of workers.

    The aim of this algorithm is to have a roughly equal number of steps on
    each worker.
    """
    // Ideal # of steps per worker before sending
    let ideal_pre: F64 = total_steps.f64() / current_workers_count.f64()
    // Ideal # of steps per worker after sending
    let ideal_post: F64 = total_steps.f64() / (current_workers_count + 1).f64()
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

    // Never send your last step.
    if (worker_portion - try_to_send) > 0 then
      try_to_send
    else
      0
    end
