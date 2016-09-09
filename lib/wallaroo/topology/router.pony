interface Router[In: Any val, RoutesTo: Any tag]
  fun route(input: In): (RoutesTo | None)

class DirectRouter[In: Any val, RoutesTo: Any tag]
  let _target: RoutesTo

  new iso create(target: RoutesTo) =>
    _target = target

  fun route(input: In): RoutesTo =>
    _target