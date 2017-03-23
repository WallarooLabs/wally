use "collections"
use "wallaroo/boundary"
use "wallaroo/topology"

interface DataChannelListenNotify
  """
  Notifications for DataChannel listeners.

  For an example of using this class, please see the documentation for the
  `DataChannelListener` actor.
  """
  fun ref listening(listen: DataChannelListener ref) =>
    """
    Called when the listener has been bound to an address.
    """
    None

  fun ref not_listening(listen: DataChannelListener ref) =>
    """
    Called if it wasn't possible to bind the listener to an address.
    """
    None

  fun ref closed(listen: DataChannelListener ref) =>
    """
    Called when the listener is closed.
    """
    None

  fun ref connected(listen: DataChannelListener ref,
    router_registry: RouterRegistry): DataChannelNotify iso^ ?
    """
    Create a new DataChannelNotify to attach to a new DataChannel for a
    newly established connection to the server.
    """
