primitive FatalUserError
  """
  An error was encountered due to bad input from the user in terms of startup
  options or configuration. Exit and inform them of the problem.
  """
  fun apply(msg: String) =>
    @fprintf[I32](
      @pony_os_stderr[Pointer[U8]](), "Error: %s\n".cstring(), msg.cstring())
    @exit[None](U8(1))
