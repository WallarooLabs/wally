trait tag CreditFlowConsumer
  be register_producer(producer: CreditFlowProducer)
  be unregister_producer(producer: CreditFlowProducer, credits_returned: USize)
  be credit_request(from: CreditFlowProducer)
