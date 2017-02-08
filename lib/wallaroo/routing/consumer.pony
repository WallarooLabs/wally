trait tag CreditFlowConsumer
  be register_producer(producer: Producer)
  be unregister_producer(producer: Producer, credits_returned: ISize)
  be credit_request(from: Producer)
  be return_credits(credits: ISize)

type CreditFlowProducerConsumer is (Producer & CreditFlowConsumer)

type Consumer is CreditFlowConsumer
