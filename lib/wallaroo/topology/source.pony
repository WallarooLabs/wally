use "net"
use "time"
use "buffered"
use "collections"
use "wallaroo/backpressure"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/tcp-source"

interface BytesProcessor
  fun ref process(data: Array[U8 val] iso)

class SourceData
  let _builder: SourceBuilderBuilder val
  let _runner_builder: RunnerBuilder val
  let _address: Array[String] val

  new val create(b: SourceBuilderBuilder val, r: RunnerBuilder val, 
    a: Array[String] val) 
  =>
    _builder = b
    _runner_builder = r
    _address = a

  fun builder(): SourceBuilderBuilder val => _builder
  fun runner_builder(): RunnerBuilder val => _runner_builder
  fun address(): Array[String] val => _address
