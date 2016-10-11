use "collections"

//TODO: generate route ids somewhere

interface Router[In: Any val, RoutesTo: Any tag]
  fun route(input: In): ((U64, RoutesTo) | None)

class DirectRouter[In: Any val, RoutesTo: Any tag]
  let _target: RoutesTo

  new iso create(target: RoutesTo) =>
    _target = target

  fun route(input: In): (U64, RoutesTo) =>
    (0,_target)

class DataRouter is Router[U128, Step tag]
  let _routes: Map[U128, Step tag] val

  new val create(routes: Map[U128, Step tag] val = 
    recover Map[U128, Step tag] end) 
  =>
    _routes = routes

  fun route(input: U128): ((U64, Step tag) | None) =>
    try
      (input.u64(),_routes(input))
    else
      None
    end
