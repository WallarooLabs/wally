trait tag Consumer
  be register_producer(producer: Producer)
  be unregister_producer(producer: Producer)

actor DummyConsumer is Consumer
  be register_producer(producer: Producer) => None
  be unregister_producer(producer: Producer) => None
