primitive JrStartupHelp
  fun apply(env: Env) =>
    env.out.print(
      """
      To run Junior:
      -----------------------------------------------------------------------------------
      --in/-i [Comma-separated list of input addresses sources listen on]
      --out/-o [Sets address for sink outputs]
      --metrics/-m [Sets address for external metrics (e.g. monitoring hub)]
      --expected/-e [Sets number of messages expected for jr metrics]
      -----------------------------------------------------------------------------------
      """
    )
