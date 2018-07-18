

// actor BarrierSource is (Producer & StatusReporter)
  // """
  // This is an artificial source whose purpose is to ensure that we have
  // at least one source available for injecting barriers into the system.
  // It's possible (with TCPSources for example) for sources to come in and
  // out of existence. We shouldn't depend on their presence to be able to
  // inject barriers.
  // """
