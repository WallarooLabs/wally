use "wallaroo/broadcast"
use "wallaroo/fail"

primitive BasicRoles
  fun ingress(): String => "ingress"

trait WActor
  fun ref receive(sender: U128, payload: Any val, h: WActorHelper)
    """
    Called when receiving a message from another WActor
    """
  fun ref process(data: Any val, h: WActorHelper)
    """
    Called when receiving data from a Wallaroo pipeline
    """

class EmptyWActor is WActor
  fun ref receive(sender: U128, payload: Any val, h: WActorHelper) =>
    Fail()
  fun ref process(data: Any val, h: WActorHelper) => Fail()

interface val WActorBuilder
  fun apply(id: U128, wh: WActorHelper): WActor

trait WActorHelper
  fun ref send_to(target: U128, data: Any val)
  fun ref send_to_role(role: String, data: Any val)
  fun ref send_to_sink[Out: Any val](sink_id: USize, output: Out)
  fun ref register_as_role(role: String)
  fun ref roles_for(w_actor: U128): Array[String]
  fun ref actors_in_role(role: String): Array[U128]
  fun ref create_actor(builder: WActorBuilder)
  fun ref destroy_actor(id: U128)
  fun ref subscribe_to_broadcast_variable(k: String)
  fun ref read_broadcast_variable(k: String): (Any val | None)
  fun ref update_broadcast_variable(k: String, v: Any val)
  fun ref set_timer(duration: U128, callback: {()},
    is_repeating: Bool = false): WActorTimer
  fun ref cancel_timer(t: WActorTimer)
