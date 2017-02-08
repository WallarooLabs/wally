use "wallaroo/topology"

type SeqId is U64
type RouteId is U64

trait RouteCallbackHandler
  fun ref register(producer: Producer ref, r: RouteLogic tag)
  fun shutdown(p: Producer ref)
  fun ref credits_initialized(producer: Producer ref, r: RouteLogic tag)
  fun ref credits_replenished(p: Producer ref)
  fun ref credits_exhausted(p: Producer ref)
