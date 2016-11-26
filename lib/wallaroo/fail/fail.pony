primitive Fail
  """
  'This should never happen' error encountered. Bail out of our running
  program. Print where the error happened and exit.
  """
  fun apply(loc: SourceLoc = __loc) =>
    @fprintf[I32](
      @pony_os_stderr[Pointer[U8]](),
      "This should never happen failure in %s at line %s\n".cstring(),
      loc.file().cstring(),
      loc.line().string().cstring())
    @exit[None](U8(1))
