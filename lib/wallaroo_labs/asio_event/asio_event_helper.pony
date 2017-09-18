primitive AsioEventHelper
  fun get_readable(ev: AsioEventID): Bool =>
    @pony_asio_event_get_readable[Bool](ev)

  fun set_readable(ev: AsioEventID, readable': Bool) =>
    @pony_asio_event_set_readable[None](ev, readable')

  fun get_writeable(ev: AsioEventID): Bool =>
    @pony_asio_event_get_writeable[Bool](ev)

  fun set_writeable(ev: AsioEventID, writeable': Bool) =>
    @pony_asio_event_set_writeable[None](ev, writeable')
