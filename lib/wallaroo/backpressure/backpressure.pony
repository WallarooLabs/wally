use "assert"
use "time"
use "sendence/guid"
use "wallaroo/boundary"
use "wallaroo/fail"
use "wallaroo/invariant"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/tcp-sink"
use "wallaroo/tcp-source"
use "wallaroo/topology"

trait tag CreditFlowConsumer
  be register_producer(producer: Producer)
  be unregister_producer(producer: Producer, credits_returned: ISize)
  be credit_request(from: Producer)
  be return_credits(credits: ISize)

type CreditFlowProducerConsumer is (Producer & CreditFlowConsumer)

type Consumer is CreditFlowConsumer

trait RouteCallbackHandler
  fun ref register(producer: Producer ref, r: Route tag)
  fun shutdown(p: Producer ref)
  fun ref credits_initialized(producer: Producer ref, r: Route tag)
  fun ref credits_replenished(p: Producer ref)
  fun ref credits_exhausted(p: Producer ref)















