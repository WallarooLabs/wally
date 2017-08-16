use "collections"
use "wallaroo/boundary"
use "wallaroo/ent/data_receiver"
use "wallaroo/messages"

trait tag LayoutInitializer
  be initialize(cluster_initializer: (ClusterInitializer | None) = None,
    recovering: Bool)

  be receive_immigrant_step(msg: StepMigrationMsg)

  be update_boundaries(bs: Map[String, OutgoingBoundary] val,
    bbs: Map[String, OutgoingBoundaryBuilder] val)

  be create_data_channel_listener(ws: Array[String] val,
    host: String, service: String,
    cluster_initializer: (ClusterInitializer | None) = None)
