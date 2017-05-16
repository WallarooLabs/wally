use "signals"

use @Py_Exit[None]()

class iso ShutdownHandler is SignalNotify
  fun ref apply(count: U32): Bool =>
    @Py_Exit()
    false
