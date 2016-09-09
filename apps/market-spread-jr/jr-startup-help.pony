primitive JrStartupHelp
  fun apply(env: Env) =>
    env.out.print(
      """
      To run Junior:
      -----------------------------------------------------------------------------------
      --in/-i [Comma-separated list of input addresses sources listen on]
      --out/-o [Sets address for sink outputs]
      --data/-d [Sets address for data channel]
      --metrics/-m [Sets address for external metrics (e.g. monitoring hub)]
      --expected/-e [Sets number of messages expected for jr metrics]
      --worker-count/-w [Sets total number of workers, including initial "leader"]
      -----------------------------------------------------------------------------------
      """
    )
