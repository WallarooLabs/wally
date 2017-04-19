use "wallaroo/fail"

trait WActor
  fun ref receive(sender: WActorId, payload: Any val)
    """
    Called when receiving a message from another WActor
    """
  fun ref process(data: Any val)
    """
    Called when receiving data from a Wallaroo pipeline
    """

class EmptyWActor is WActor
  fun ref receive(sender: WActorId, payload: Any val) =>
    Fail()
  fun ref process(data: Any val) => Fail()

interface val WActorBuilder
  fun apply(id: U128, wh: WActorHelper): WActor

class WActorHelper
  let _w_actor: WActorWrapper ref

  new create(w_actor: WActorWrapper ref) =>
    _w_actor = w_actor

  fun ref send_to(target: WActorId, data: Any val) =>
    _w_actor._send_to(target, data)

  fun ref send_to_role(role: String, data: Any val) =>
    _w_actor._send_to_role(role, data)

  fun ref register_as_role(role: String) =>
    _w_actor._register_as_role(role)

  fun known_actors(): Array[WActorId] val =>
    _w_actor._known_actors()

  fun ref set_timer(duration: U128, callback: {()},
    is_repeating: Bool = false): WActorTimer
  =>
    _w_actor._set_timer(duration, callback, is_repeating)

  fun ref cancel_timer(t: WActorTimer) =>
    _w_actor._cancel_timer(t)








