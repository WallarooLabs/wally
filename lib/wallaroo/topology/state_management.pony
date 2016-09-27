trait StateChange[State: Any #read]
  fun apply(state: State)
  fun to_log_entry(): Array[U8]
  fun read_log_entry(entry: Array[U8])
