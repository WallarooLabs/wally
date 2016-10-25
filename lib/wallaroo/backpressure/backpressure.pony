trait tag CreditFlowConsumer
  be register_producer(producer: CreditFlowProducer)
  be unregister_producer(producer: CreditFlowProducer, credits_returned: USize)
  be credit_request(from: CreditFlowProducer)

trait tag CreditFlowProducer
  be receive_credits(credits: USize, from: CreditFlowConsumer)
  fun ref credit_used(c: CreditFlowConsumer, num: USize = 1)

type CreditFlowProducerConsumer is (CreditFlowProducer & CreditFlowConsumer)
