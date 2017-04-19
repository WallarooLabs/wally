use "time"

actor Ticker
  let _central_actor_registry: CentralWActorRegistry
  let _timers: Timers = Timers

  new create(car: CentralWActorRegistry, interval: U64 = 1_000_000_000) =>
    _central_actor_registry = car
    let timer: Timer iso = Timer(TickTimerNotify(_central_actor_registry),
      interval, interval)
    _timers(consume timer)

  be tick() =>
    _central_actor_registry.tick()


class TickTimerNotify is TimerNotify
  let _central_actor_registry: CentralWActorRegistry

  new iso create(registry: CentralWActorRegistry) =>
    _central_actor_registry = registry

  fun ref apply(timer: Timer, count: U64): Bool =>
    _central_actor_registry.tick()
    true
