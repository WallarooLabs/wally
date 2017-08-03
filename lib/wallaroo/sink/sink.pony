use "wallaroo/metrics"
use "wallaroo/routing"
use "wallaroo/topology"

type Sink is (Consumer & RunnableStep & Initializable tag)

interface val SinkConfig[Out: Any val]
  fun apply(): SinkBuilder

interface val SinkBuilder
  fun apply(reporter: MetricsReporter iso): Sink
