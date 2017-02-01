trait tag CreditFlowConsumer
  be register_producer(producer: Producer)
  be unregister_producer(producer: Producer)

type CreditFlowProducerConsumer is (Producer & CreditFlowConsumer)

type Consumer is CreditFlowConsumer
