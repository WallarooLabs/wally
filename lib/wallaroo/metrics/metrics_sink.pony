use "wallaroo/core"

interface tag MetricsSink is DisposableActor
  be send_metrics(metrics: MetricDataList val)
  fun ref set_nodelay(state: Bool)
  be writev(data: ByteSeqIter)
