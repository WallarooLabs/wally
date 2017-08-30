primitive Unreachable
  """
  `Fail` with a more explicit message. To be used with code that should fail
  if it reaches an "unreachable" point.
  """
  fun apply(loc: SourceLoc = __loc) =>
    @fprintf[I32](
      @pony_os_stderr[Pointer[U8]](),
      "The unreachable was reached in %s at line %s\n".cstring(),
      loc.file().cstring(),
      loc.line().string().cstring())
    @exit[None](U8(1))
