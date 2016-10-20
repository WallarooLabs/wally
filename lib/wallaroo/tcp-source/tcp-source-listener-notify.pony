interface SourceBuilder
  fun ref apply(listen: TCPSourceListener ref): TCPSourceNotify iso^ ?

interface TCPSourceListenerNotify
  """
  Notifications for TCPSource listeners.
  """
  fun ref listening(listen: TCPSourceListener ref) =>
    """
    Called when the listener has been bound to an address.
    """
    None

  fun ref not_listening(listen: TCPSourceListener ref) =>
    """
    Called if it wasn't possible to bind the listener to an address.
    """
    None

  fun ref connected(listen: TCPSourceListener ref): TCPSourceNotify iso^ ?
    """
    Create a new TCPSourceNotify to attach to a new TCPSource for a
    newly established connection to the server.
    """

class SourceListenerNotify is TCPSourceListenerNotify
  let _source_builder: SourceBuilder

  new iso create(builder: SourceBuilder iso) =>
    _source_builder = consume builder

  fun ref connected(listen: TCPSourceListener ref): TCPSourceNotify iso^ ? =>
    _source_builder(listen)

  // TODO: implement listening and especially not_listening


