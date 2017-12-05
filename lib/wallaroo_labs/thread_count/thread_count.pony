primitive ThreadCount
  fun apply(): USize =>
    @ponyint_sched_cores[I32]().usize()
