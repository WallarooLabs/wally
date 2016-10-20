trait tag CreditFlowProducer
  be receive_credits(credits: USize, from: CreditFlowConsumer)
  fun ref credit_used(c: CreditFlowConsumer, num: USize = 1)
