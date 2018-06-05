/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "ponytest"
use "wallaroo/core/common"
use "wallaroo/core/topology"
use "wallaroo/core/routing"

actor _TestOutgoingToIncomingMessageTracker is TestList
  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(_TestEmptyIndexFor)
    test(_TestBelowFirstIndex)
    test(_TestIndexFor1)
    test(_TestIndexFor2)
    test(_TestIndexForWithGaps)
    test(_TestIndexForWithGaps2)
    test(_TestProducerHighsBelow1)
    test(_TestProducerHighsBelow2)
    test(_TestProducerHighsBelowWithOneToManyPartiallyAcked)
    test(_TestProducerHighsBelowWithOneToManyFullyAcked1)
    test(_TestProducerHighsBelowWithOneToManyFullyAcked2)
    test(_TestOutgoingToIncomingEviction)
    test(_TestOutgoingToIncomingEvictionBelow)

class iso _TestEmptyIndexFor is UnitTest
  fun name(): String =>
    "outgoing_to_incoming_message_tracker/EmptyIndexFor"

  fun ref apply(h: TestHelper) =>
    let t = _OutgoingToIncomingMessageTracker

    h.assert_eq[USize](-1, t._index_for(1))

class iso _TestBelowFirstIndex is UnitTest
  fun name(): String =>
    "outgoing_to_incoming_message_tracker/BelowFirstIndex"

  fun ref apply(h: TestHelper) =>
    let t = _OutgoingToIncomingMessageTracker

    t.add(SeqId(2), _TestProducer, RouteId(1), SeqId(1))

    h.assert_eq[USize](-1, t._index_for(1))

class iso _TestIndexFor1 is UnitTest
  fun name(): String =>
    "outgoing_to_incoming_message_tracker/IndexFor1"

  fun ref apply(h: TestHelper) =>
    let t = _OutgoingToIncomingMessageTracker

    t.add(SeqId(1), _TestProducer, RouteId(1), SeqId(1))
    t.add(SeqId(2), _TestProducer, RouteId(1), SeqId(2))
    t.add(SeqId(3), _TestProducer, RouteId(1), SeqId(3))
    t.add(SeqId(4), _TestProducer, RouteId(1), SeqId(4))
    t.add(SeqId(5), _TestProducer, RouteId(1), SeqId(5))
    t.add(SeqId(6), _TestProducer, RouteId(1), SeqId(6))

    h.assert_eq[USize](0, t._index_for(1))
    h.assert_eq[USize](1, t._index_for(2))
    h.assert_eq[USize](2, t._index_for(3))
    h.assert_eq[USize](3, t._index_for(4))
    h.assert_eq[USize](4, t._index_for(5))
    h.assert_eq[USize](5, t._index_for(6))

class iso _TestIndexFor2 is UnitTest
  fun name(): String =>
    "outgoing_to_incoming_message_tracker/IndexFor2"

  fun ref apply(h: TestHelper) =>
    let t = _OutgoingToIncomingMessageTracker

    t.add(SeqId(505), _TestProducer, RouteId(1), SeqId(10))
    t.add(SeqId(506), _TestProducer, RouteId(1), SeqId(11))
    t.add(SeqId(507), _TestProducer, RouteId(1), SeqId(12))
    t.add(SeqId(508), _TestProducer, RouteId(1), SeqId(13))
    t.add(SeqId(509), _TestProducer, RouteId(1), SeqId(14))
    t.add(SeqId(510), _TestProducer, RouteId(1), SeqId(15))

    h.assert_eq[USize](0, t._index_for(505))
    h.assert_eq[USize](1, t._index_for(506))
    h.assert_eq[USize](2, t._index_for(507))
    h.assert_eq[USize](3, t._index_for(508))
    h.assert_eq[USize](4, t._index_for(509))
    h.assert_eq[USize](5, t._index_for(510))

class iso _TestIndexForWithGaps is UnitTest
  fun name(): String =>
    "outgoing_to_incoming_message_tracker/IndexForWithGaps"

  fun ref apply(h: TestHelper) =>
    let t = _OutgoingToIncomingMessageTracker

    t.add(SeqId(505), _TestProducer, RouteId(1), SeqId(10))
    t.add(SeqId(516), _TestProducer, RouteId(1), SeqId(11))
    t.add(SeqId(527), _TestProducer, RouteId(1), SeqId(12))
    t.add(SeqId(538), _TestProducer, RouteId(1), SeqId(13))
    t.add(SeqId(549), _TestProducer, RouteId(1), SeqId(14))
    t.add(SeqId(551), _TestProducer, RouteId(1), SeqId(15))

    h.assert_eq[USize](0, t._index_for(505))
    h.assert_eq[USize](1, t._index_for(516))
    h.assert_eq[USize](2, t._index_for(527))
    h.assert_eq[USize](3, t._index_for(538))
    h.assert_eq[USize](4, t._index_for(549))
    h.assert_eq[USize](5, t._index_for(551))

class iso _TestIndexForWithGaps2 is UnitTest
  """
  Test that index for correctly finds values when the SeqId we are
  searching for doesn't exist in our map because it's a SeqId that
  is part of a 1-to-many sequence.
  """
  fun name(): String =>
    "outgoing_to_incoming_message_tracker/IndexForWithGaps2"

  fun ref apply(h: TestHelper) =>
    let t = _OutgoingToIncomingMessageTracker

    t.add(SeqId(505), _TestProducer, RouteId(1), SeqId(10))
    t.add(SeqId(516), _TestProducer, RouteId(1), SeqId(11))
    t.add(SeqId(527), _TestProducer, RouteId(1), SeqId(12))
    t.add(SeqId(538), _TestProducer, RouteId(1), SeqId(13))
    t.add(SeqId(549), _TestProducer, RouteId(1), SeqId(14))
    t.add(SeqId(551), _TestProducer, RouteId(1), SeqId(15))

    h.assert_eq[USize](0, t._index_for(508))
    h.assert_eq[USize](1, t._index_for(518))
    h.assert_eq[USize](2, t._index_for(531))
    h.assert_eq[USize](3, t._index_for(542))
    h.assert_eq[USize](4, t._index_for(550))

class iso _TestProducerHighsBelow1 is UnitTest
  """
  Test producer highs below when there are multiple
  messages that went out on the route below the SeqId that
  we are getting up to.
  """
  fun name(): String =>
    "outgoing_to_incoming_message_tracker/ProducerHighsBelow1"

  fun ref apply(h: TestHelper) =>
    let o1 = _TestProducer
    let o1route = RouteId(1)
    let o2 = _TestProducer
    let o2route = RouteId(3)
    let t = _OutgoingToIncomingMessageTracker

    t.add(SeqId(1), o1, o1route, SeqId(1))
    t.add(SeqId(2), o2, o2route, SeqId(1))
    t.add(SeqId(3), o1, o1route, SeqId(2))
    t.add(SeqId(4), o1, o1route, SeqId(3))
    t.add(SeqId(5), o2, o2route, SeqId(2))
    t.add(SeqId(6), o1, o1route, SeqId(4))

    let highs = t._producer_highs_below(SeqId(5))
    h.assert_eq[USize](2, highs.size())
    h.assert_true(highs.contains((o1, o1route)))
    h.assert_true(highs.contains((o2, o2route)))
    try
      h.assert_eq[U64](SeqId(3), highs((o1, o1route))?)
      h.assert_eq[U64](SeqId(2), highs((o2, o2route))?)
    else
      h.fail()
    end

class iso _TestProducerHighsBelow2 is UnitTest
  """
  Test _producer_high_below correctly only gets first item in
  and not others.
  """
  fun name(): String =>
    "outgoing_to_incoming_message_tracker/ProducerHighsBelow2"

  fun ref apply(h: TestHelper) =>
    let o1 = _TestProducer
    let o1route = RouteId(1)
    let o2 = _TestProducer
    let o2route = RouteId(3)
    let t = _OutgoingToIncomingMessageTracker

    t.add(SeqId(1), o1, o1route, SeqId(1))
    t.add(SeqId(2), o2, o2route, SeqId(1))
    t.add(SeqId(3), o1, o1route, SeqId(2))
    t.add(SeqId(4), o1, o1route, SeqId(3))
    t.add(SeqId(5), o2, o2route, SeqId(2))
    t.add(SeqId(6), o1, o1route, SeqId(4))

    let highs = t._producer_highs_below(SeqId(1))
    h.assert_eq[USize](1, highs.size())
    h.assert_true(highs.contains((o1, o1route)))
    h.assert_false(highs.contains((o2, o2route)))
    try
      h.assert_eq[U64](SeqId(1), highs((o1, o1route))?)
    else
      h.fail()
    end

class iso _TestProducerHighsBelowWithOneToManyPartiallyAcked is UnitTest
  fun name(): String =>
    "outgoing_to_incoming_message_tracker/ProducerHighsBelowWithOneToManyPartiallyAcked"

  fun ref apply(h: TestHelper) =>
    let o1 = _TestProducer
    let o1route = RouteId(1)
    let o2 = _TestProducer
    let o2route = RouteId(3)
    let t = _OutgoingToIncomingMessageTracker

    t.add(SeqId(1), o1, o1route, SeqId(1))
    // this incoming message is 1 to many
    // in particular (o2, o2route, SeqId(1)) results in 4 outgoing messages
    t.add(SeqId(5), o2, o2route, SeqId(1))

    t.add(SeqId(6), o1, o1route, SeqId(2))
    t.add(SeqId(7), o1, o1route, SeqId(3))
    t.add(SeqId(8), o2, o2route, SeqId(2))
    t.add(SeqId(9), o1, o1route, SeqId(4))

    let highs = t._producer_highs_below(SeqId(4))
    h.assert_eq[USize](1, highs.size())
    h.assert_true(highs.contains((o1, o1route)))
    h.assert_false(highs.contains((o2, o2route)))
    try
      h.assert_eq[U64](SeqId(1), highs((o1, o1route))?)
    else
      h.fail()
    end

class iso _TestProducerHighsBelowWithOneToManyFullyAcked1 is UnitTest
  fun name(): String =>
    "outgoing_to_incoming_message_tracker/ProducerHighsBelowWithOneToManyFullyAcked1"

  fun ref apply(h: TestHelper) =>
    let o1 = _TestProducer
    let o1route = RouteId(1)
    let o2 = _TestProducer
    let o2route = RouteId(3)
    let t = _OutgoingToIncomingMessageTracker

    t.add(SeqId(1), o1, o1route, SeqId(1))
    // this incoming message is 1 to many
    // in particular (o2, o2route, SeqId(1)) results in 4 outgoing messages
    t.add(SeqId(5), o2, o2route, SeqId(1))

    t.add(SeqId(6), o1, o1route, SeqId(2))
    t.add(SeqId(7), o1, o1route, SeqId(3))
    t.add(SeqId(8), o2, o2route, SeqId(2))
    t.add(SeqId(9), o1, o1route, SeqId(4))

    let highs = t._producer_highs_below(SeqId(5))
    h.assert_eq[USize](2, highs.size())
    h.assert_true(highs.contains((o1, o1route)))
    h.assert_true(highs.contains((o2, o2route)))
    try
      h.assert_eq[U64](SeqId(1), highs((o1, o1route))?)
      h.assert_eq[U64](SeqId(1), highs((o2, o2route))?)
    else
      h.fail()
    end

class iso _TestProducerHighsBelowWithOneToManyFullyAcked2 is UnitTest
  fun name(): String =>
    "outgoing_to_incoming_message_tracker/ProducerHighsBelowWithOneToManyFullyAcked2"

  fun ref apply(h: TestHelper) =>
    let o1 = _TestProducer
    let o1route = RouteId(1)
    let o2 = _TestProducer
    let o2route = RouteId(3)
    let t = _OutgoingToIncomingMessageTracker

    t.add(SeqId(1), o1, o1route, SeqId(1))
    // this incoming message is 1 to many
    // in particular (o2, o2route, SeqId(1)) results in 4 outgoing messages
    t.add(SeqId(5), o2, o2route, SeqId(1))

    t.add(SeqId(6), o1, o1route, SeqId(2))
    t.add(SeqId(7), o1, o1route, SeqId(3))
    t.add(SeqId(8), o2, o2route, SeqId(2))
    t.add(SeqId(9), o1, o1route, SeqId(4))

    let highs = t._producer_highs_below(SeqId(8))

    h.assert_eq[USize](2, highs.size())
    h.assert_true(highs.contains((o1, o1route)))
    h.assert_true(highs.contains((o2, o2route)))
    try
      h.assert_eq[U64](SeqId(3), highs((o1, o1route))?)
      h.assert_eq[U64](SeqId(2), highs((o2, o2route))?)
    else
      h.fail()
    end

class iso _TestProducerHighsBelowWithOneToManyFullyAcked3 is UnitTest
  fun name(): String =>
    "outgoing_to_incoming_message_tracker/ProducerHighsBelowWithOneToManyFullyAcked3"

  fun ref apply(h: TestHelper) =>
    let o1 = _TestProducer
    let o1route = RouteId(1)
    let o2 = _TestProducer
    let o2route = RouteId(3)
    let t = _OutgoingToIncomingMessageTracker

    t.add(SeqId(1), o1, o1route, SeqId(1))
    // this incoming message is 1 to many
    // in particular (o2, o2route, SeqId(1)) results in 4 outgoing messages
    t.add(SeqId(5), o2, o2route, SeqId(1))

    t.add(SeqId(6), o1, o1route, SeqId(2))
    t.add(SeqId(7), o1, o1route, SeqId(3))
    t.add(SeqId(8), o2, o2route, SeqId(2))
    t.add(SeqId(9), o1, o1route, SeqId(4))

    let highs = t._producer_highs_below(SeqId(7))
    h.assert_eq[USize](2, highs.size())
    h.assert_true(highs.contains((o1, o1route)))
    h.assert_true(highs.contains((o2, o2route)))
    try
      h.assert_eq[U64](SeqId(3), highs((o1, o1route))?)
      h.assert_eq[U64](SeqId(1), highs((o2, o2route))?)
    else
      h.fail()
    end

class iso _TestOutgoingToIncomingEviction is UnitTest
  fun name(): String =>
    "outgoing_to_incoming_message_tracker/OutgoingToIncomingEviction"

  fun ref apply(h: TestHelper) =>
    let o1 = _TestProducer
    let o1route = RouteId(1)
    let o2 = _TestProducer
    let o2route = RouteId(3)
    let t = _OutgoingToIncomingMessageTracker

    t.add(SeqId(1), o1, o1route, SeqId(1))
    t.add(SeqId(2), o2, o2route, SeqId(1))
    t.add(SeqId(3), o1, o1route, SeqId(2))
    t.add(SeqId(4), o1, o1route, SeqId(3))
    t.add(SeqId(5), o2, o2route, SeqId(2))
    t.add(SeqId(6), o1, o1route, SeqId(4))

    let evict_through = SeqId(3)

    t.evict(evict_through)
    h.assert_eq[USize](3, t._size())
    h.assert_false(t._contains(SeqId(1)))
    h.assert_false(t._contains(SeqId(2)))
    h.assert_false(t._contains(SeqId(3)))
    h.assert_true(t._contains(SeqId(4)))
    h.assert_true(t._contains(SeqId(5)))
    h.assert_true(t._contains(SeqId(6)))

class iso _TestOutgoingToIncomingEvictionBelow is UnitTest
  fun name(): String =>
    "outgoing_to_incoming_message_tracker/OutgoingToIncomingEvictionBelow"

  fun ref apply(h: TestHelper) =>
    let o1 = _TestProducer
    let o1route = RouteId(1)
    let o2 = _TestProducer
    let o2route = RouteId(3)
    let t = _OutgoingToIncomingMessageTracker


    t.add(SeqId(5), o2, o2route, SeqId(2))
    t.add(SeqId(6), o1, o1route, SeqId(4))

    let evict_through = SeqId(3)

    t.evict(evict_through)
    h.assert_eq[USize](2, t._size())
    h.assert_true(t._contains(SeqId(5)))
    h.assert_true(t._contains(SeqId(6)))

actor _TestProducer is Producer
  be mute(c: Consumer) =>
    None

  be unmute(c: Consumer) =>
    None

  fun ref route_to(c: Consumer): (Route | None) =>
    None

  fun ref next_sequence_id(): SeqId =>
    0

  fun ref current_sequence_id(): SeqId =>
    0

  be unknown_key(state_name: String, key: Key, data: Any val) =>
    None

  be update_keyed_route(state_name: String, key: Key, step: Step,
    step_id: StepId)
  =>
    None

  fun ref _acker(): Acker =>
    Acker

  fun ref flush(low_watermark: SeqId) =>
    None

  fun ref update_router(router: Router) =>
    None

  be remove_route_to_consumer(c: Consumer) =>
    None

  be request_ack() =>
    None

  be receive_in_flight_ack(request_id: RequestId) =>
    None

  be receive_in_flight_resume_ack(request_id: RequestId) =>
    None

  be try_finish_in_flight_request_early(requester_id: StepId) =>
    None
