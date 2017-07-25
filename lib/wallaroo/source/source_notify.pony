use "collections"
use "wallaroo/boundary"
use "wallaroo/messages"
use "wallaroo/routing"
use "wallaroo/topology"

interface SourceNotify
  fun ref routes(): Array[ConsumerStep] val

  fun ref update_router(router: Router val)

  fun ref update_boundaries(obs: box->Map[String, OutgoingBoundary])
