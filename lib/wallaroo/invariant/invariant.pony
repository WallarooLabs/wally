"""
# Invariant package

Wallaroo specific variation on the standard Pony "Assert" functionality.
Wraps our usual assertion logic into a new clean primitive.
"""

primitive Invariant
  """
  This is a debug only assertion. If the test is false, it will print
  'Invariant violated' along with the source file location of the
  invariant to stderr and then forcibly exit the program.
  """
  fun apply(test: Bool, loc: SourceLoc = __loc) =>
    ifdef debug then
      if not test then
        @fprintf[I32](
          @pony_os_stderr[Pointer[U8]](),
          "Invariant violated in %s at line %s\n".cstring(),
          loc.file().cstring(),
          loc.line().string().cstring())
        @exit[None](U8(1))
      end
    end
