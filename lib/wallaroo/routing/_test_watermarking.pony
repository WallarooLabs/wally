use "sendence/connemara"

use "wallaroo/topology"

actor TestWatermarking is TestList
  new make() =>
    None

  fun tag tests(test: Connemara) =>
    test(_TestDataReceiverProposeWatermarkFullyAcked)
    test(_TestDataReceiverProposeWatermark1)
    test(_TestDataReceiverProposeWatermark2)
    test(_TestDataReceiverProposeWatermark3)
    test(_TestDataReceiverProposeWatermark4)
    test(_TestDataReceiverProposeWatermark5)
    test(_TestOutgoingToIncomingEmptyIndexFor)
    test(_TestOutgoingToIncomingIndexFor1)
    test(_TestOutgoingToIncomingIndexFor2)
    test(_TestOriginHighsBelow1)
    test(_TestOriginHighsBelow2)
    test(_TestOriginHighsBelowWithOneToManyPartiallyAcked)
    test(_TestOriginHighsBelowWithOneToManyFullyAcked1)
    test(_TestOriginHighsBelowWithOneToManyFullyAcked2)
    test(_TestOriginHighsBelowWithOneToManyFullyAcked3)
    test(_TestOutgoingToIncomingEviction)
    test(_TestOutgoingToIncomingBadEviction)

///
///
class iso _TestDataReceiverProposeWatermarkFullyAcked is UnitTest
  """
  Test we get the correct proposed watermark when
  all routes are fully acked
  """
  fun name(): String =>
    "watermarking/DataReceiverProposeWatermarkFullyAcked"

  fun ref apply(h: TestHelper) =>
    let routes: DataReceiverRoutes = DataReceiverRoutes
    let route_id_1 = RouteId(1)
    let route_id_2 = RouteId(2)
    routes.add_route(route_id_1)
    routes.add_route(route_id_2)

    routes.send(route_id_1, SeqId(2))
    routes.send(route_id_2, SeqId(3))

    routes.receive_ack(route_id_1, SeqId(2))
    routes.receive_ack(route_id_2, SeqId(3))

    let proposed: SeqId = routes.propose_new_watermark()
    h.assert_eq[SeqId](3, proposed)

class iso _TestDataReceiverProposeWatermark1 is UnitTest
  """
  Route | Sent | Ack
  A       0     0
  B       2     1
  C       5     5
  D       7     4

  Should be 1
  """
  fun name(): String =>
    "watermarking/DataReceiverProposeWatermark1"

  fun ref apply(h: TestHelper) =>
    let routes: DataReceiverRoutes = DataReceiverRoutes
    let route_id_1 = RouteId(1)
    let route_id_2 = RouteId(2)
    let route_id_3 = RouteId(3)
    routes.add_route(route_id_1)
    routes.add_route(route_id_2)
    routes.add_route(route_id_3)

    routes.send(route_id_1, SeqId(1))
    routes.send(route_id_1, SeqId(2))
    routes.receive_ack(route_id_1, SeqId(1))

    routes.send(route_id_2, SeqId(5))
    routes.receive_ack(route_id_2, SeqId(5))

    routes.send(route_id_3, SeqId(4))
    routes.send(route_id_3, SeqId(6))
    routes.send(route_id_3, SeqId(7))
    routes.receive_ack(route_id_3, SeqId(4))

    let proposed: SeqId = routes.propose_new_watermark()
    h.assert_eq[SeqId](1, proposed)

class iso _TestDataReceiverProposeWatermark2 is UnitTest
  """
  Route | Sent | Ack
    A       0     0
    B       3     1
    C       5     5
    D       7     4

  Should be 1
  """
  fun name(): String =>
    "watermarking/DataReceiverProposeWatermark2"

  fun ref apply(h: TestHelper) =>
    let routes: DataReceiverRoutes = DataReceiverRoutes
    let route_id_1 = RouteId(1)
    let route_id_2 = RouteId(2)
    let route_id_3 = RouteId(3)
    routes.add_route(route_id_1)
    routes.add_route(route_id_2)
    routes.add_route(route_id_3)

    routes.send(route_id_1, SeqId(1))
    routes.send(route_id_1, SeqId(2))
    routes.send(route_id_1, SeqId(3))
    routes.receive_ack(route_id_1, SeqId(1))

    routes.send(route_id_2, SeqId(5))
    routes.receive_ack(route_id_2, SeqId(5))

    routes.send(route_id_3, SeqId(4))
    routes.send(route_id_3, SeqId(6))
    routes.send(route_id_3, SeqId(7))
    routes.receive_ack(route_id_3, SeqId(4))

    let proposed: SeqId = routes.propose_new_watermark()
    h.assert_eq[SeqId](1, proposed)

class iso _TestDataReceiverProposeWatermark3 is UnitTest
  """
  Route | Sent | Ack
    A       0     0
    B       9     1
    C       5     5
    D       7     4

  Should be 1
  """
  fun name(): String =>
    "watermarking/DataReceiverProposeWatermark3"

  fun ref apply(h: TestHelper) =>
    let routes: DataReceiverRoutes = DataReceiverRoutes
    let route_id_1 = RouteId(1)
    let route_id_2 = RouteId(2)
    let route_id_3 = RouteId(3)
    routes.add_route(route_id_1)
    routes.add_route(route_id_2)
    routes.add_route(route_id_3)

    routes.send(route_id_1, SeqId(1))
    routes.send(route_id_1, SeqId(3))
    routes.send(route_id_1, SeqId(8))
    routes.send(route_id_1, SeqId(9))
    routes.receive_ack(route_id_1, SeqId(1))

    routes.send(route_id_2, SeqId(5))
    routes.receive_ack(route_id_2, SeqId(5))

    routes.send(route_id_3, SeqId(4))
    routes.send(route_id_3, SeqId(6))
    routes.send(route_id_3, SeqId(7))
    routes.receive_ack(route_id_3, SeqId(4))

    let proposed: SeqId = routes.propose_new_watermark()
    h.assert_eq[SeqId](1, proposed)

class iso _TestDataReceiverProposeWatermark4 is UnitTest
  """
  Route | Sent | Ack
    A       9     3
    B       5     5
    C       0     0

  Should be 3
  """
  fun name(): String =>
    "watermarking/DataReceiverProposeWatermark4"

  fun ref apply(h: TestHelper) =>
    let routes: DataReceiverRoutes = DataReceiverRoutes
    let route_id_1 = RouteId(1)
    let route_id_2 = RouteId(2)
    let route_id_3 = RouteId(3)
    routes.add_route(route_id_1)
    routes.add_route(route_id_2)
    routes.add_route(route_id_3)

    routes.send(route_id_1, SeqId(3))
    routes.send(route_id_1, SeqId(8))
    routes.send(route_id_1, SeqId(9))
    routes.receive_ack(route_id_1, SeqId(3))

    routes.send(route_id_2, SeqId(5))
    routes.receive_ack(route_id_2, SeqId(5))

    let proposed: SeqId = routes.propose_new_watermark()
    h.assert_eq[SeqId](3, proposed)

class iso _TestDataReceiverProposeWatermark5 is UnitTest
  """
  Route | Sent | Ack
    A       9     3
    B       5     5
    C       1     0

  Should be 0
  """
  fun name(): String =>
    "watermarking/DataReceiverProposeWatermark5"

  fun ref apply(h: TestHelper) =>
    let routes: DataReceiverRoutes = DataReceiverRoutes
    let route_id_1 = RouteId(1)
    let route_id_2 = RouteId(2)
    let route_id_3 = RouteId(3)
    routes.add_route(route_id_1)
    routes.add_route(route_id_2)
    routes.add_route(route_id_3)

    routes.send(route_id_1, SeqId(3))
    routes.send(route_id_1, SeqId(8))
    routes.send(route_id_1, SeqId(9))
    routes.receive_ack(route_id_1, SeqId(3))

    routes.send(route_id_2, SeqId(5))
    routes.receive_ack(route_id_2, SeqId(5))

    routes.send(route_id_3, SeqId(1))

    let proposed: SeqId = routes.propose_new_watermark()
    h.assert_eq[SeqId](0, proposed)
///
///

class iso _TestOutgoingToIncomingEmptyIndexFor is UnitTest
  """
  Trying to get an index of a non-existent item should
  throw an error
  """
  fun name(): String =>
    "watermarking/OutgoingToIncomingEmptyIndexFor"

  fun ref apply(h: TestHelper) =>
    let t = _OutgoingToIncoming

    try
      t._index_for(1)
      h.fail()
    end

class iso _TestOutgoingToIncomingIndexFor1 is UnitTest
  fun name(): String =>
    "watermarking/OutgoingToIncomingIndexFor1"

  fun ref apply(h: TestHelper) =>
    let t = _OutgoingToIncoming

    t.add(SeqId(1), _TestProducer, RouteId(1), SeqId(1))
    t.add(SeqId(2), _TestProducer, RouteId(1), SeqId(2))
    t.add(SeqId(3), _TestProducer, RouteId(1), SeqId(3))
    t.add(SeqId(4), _TestProducer, RouteId(1), SeqId(4))
    t.add(SeqId(5), _TestProducer, RouteId(1), SeqId(5))
    t.add(SeqId(6), _TestProducer, RouteId(1), SeqId(6))

    try
      h.assert_eq[USize](0, t._index_for(1))
      h.assert_eq[USize](1, t._index_for(2))
      h.assert_eq[USize](2, t._index_for(3))
      h.assert_eq[USize](3, t._index_for(4))
      h.assert_eq[USize](4, t._index_for(5))
      h.assert_eq[USize](5, t._index_for(6))
    else
      h.fail()
    end


class iso _TestOutgoingToIncomingIndexFor2 is UnitTest
  fun name(): String =>
    "watermarking/OutgoingToIncomingIndexFor2"

  fun ref apply(h: TestHelper) =>
    let t = _OutgoingToIncoming

    t.add(SeqId(505), _TestProducer, RouteId(1), SeqId(10))
    t.add(SeqId(506), _TestProducer, RouteId(1), SeqId(11))
    t.add(SeqId(507), _TestProducer, RouteId(1), SeqId(12))
    t.add(SeqId(508), _TestProducer, RouteId(1), SeqId(13))
    t.add(SeqId(509), _TestProducer, RouteId(1), SeqId(14))
    t.add(SeqId(510), _TestProducer, RouteId(1), SeqId(15))

    try
      h.assert_eq[USize](0, t._index_for(505))
      h.assert_eq[USize](1, t._index_for(506))
      h.assert_eq[USize](2, t._index_for(507))
      h.assert_eq[USize](3, t._index_for(508))
      h.assert_eq[USize](4, t._index_for(509))
      h.assert_eq[USize](5, t._index_for(510))
    else
      h.fail()
    end

class iso _TestOriginHighsBelow1 is UnitTest
  fun name(): String =>
    "watermarking/OriginHighsBelow1"

  fun ref apply(h: TestHelper) =>
    let o1 = _TestProducer
    let o1route = RouteId(1)
    let o2 = _TestProducer
    let o2route = RouteId(3)
    let t = _OutgoingToIncoming

    t.add(SeqId(1), o1, o1route, SeqId(1))
    t.add(SeqId(2), o2, o2route, SeqId(1))
    t.add(SeqId(3), o1, o1route, SeqId(2))
    t.add(SeqId(4), o1, o1route, SeqId(3))
    t.add(SeqId(5), o2, o2route, SeqId(2))
    t.add(SeqId(6), o1, o1route, SeqId(4))

    let index: USize = 4
    try
      h.assert_eq[USize](index, t._index_for(SeqId(5)))
    else
      h.fail()
    end

    let highs = t._origin_highs_below(index)

    h.assert_eq[USize](2, highs.size())
    h.assert_true(highs.contains((o1, o1route)))
    h.assert_true(highs.contains((o2, o2route)))
    try
      h.assert_eq[U64](SeqId(3), highs((o1, o1route)))
      h.assert_eq[U64](SeqId(2), highs((o2, o2route)))
    else
      h.fail()
    end

class iso _TestOriginHighsBelow2 is UnitTest
  fun name(): String =>
    "watermarking/OriginHighsBelow2"

  fun ref apply(h: TestHelper) =>
    let o1 = _TestProducer
    let o1route = RouteId(1)
    let o2 = _TestProducer
    let o2route = RouteId(3)
    let t = _OutgoingToIncoming

    t.add(SeqId(1), o1, o1route, SeqId(1))
    t.add(SeqId(2), o2, o2route, SeqId(1))
    t.add(SeqId(3), o1, o1route, SeqId(2))
    t.add(SeqId(4), o1, o1route, SeqId(3))
    t.add(SeqId(5), o2, o2route, SeqId(2))
    t.add(SeqId(6), o1, o1route, SeqId(4))

    let index: USize = 0
    try
      h.assert_eq[USize](index, t._index_for(SeqId(1)))
    else
      h.fail()
    end
    let highs = t._origin_highs_below(index)

    h.assert_eq[USize](1, highs.size())
    h.assert_true(highs.contains((o1, o1route)))
    h.assert_false(highs.contains((o2, o2route)))
    try
      h.assert_eq[U64](SeqId(1), highs((o1, o1route)))
    else
      h.fail()
    end

class iso _TestOriginHighsBelowWithOneToManyPartiallyAcked is UnitTest
  fun name(): String =>
    "watermarking/OriginHighsBelowWithOneToManyPartiallyAcked"

  fun ref apply(h: TestHelper) =>
    let o1 = _TestProducer
    let o1route = RouteId(1)
    let o2 = _TestProducer
    let o2route = RouteId(3)
    let t = _OutgoingToIncoming

    t.add(SeqId(1), o1, o1route, SeqId(1))
    // this incoming message is 1 to many
    // in particular (o2, o2route, SeqId(1)) results in 4 outgoing messages
    t.add(SeqId(2), o2, o2route, SeqId(1))
    t.add(SeqId(3), o2, o2route, SeqId(1))
    t.add(SeqId(4), o2, o2route, SeqId(1))
    t.add(SeqId(5), o2, o2route, SeqId(1))

    t.add(SeqId(6), o1, o1route, SeqId(2))
    t.add(SeqId(7), o1, o1route, SeqId(3))
    t.add(SeqId(8), o2, o2route, SeqId(2))
    t.add(SeqId(9), o1, o1route, SeqId(4))

    let index: USize = 3
    try
      h.assert_eq[USize](index, t._index_for(SeqId(4)))
    else
      h.fail()
    end
    let highs = t._origin_highs_below(index)

    h.assert_eq[USize](1, highs.size())
    h.assert_true(highs.contains((o1, o1route)))
    h.assert_false(highs.contains((o2, o2route)))
    try
      h.assert_eq[U64](SeqId(1), highs((o1, o1route)))
    else
      h.fail()
    end

class iso _TestOriginHighsBelowWithOneToManyFullyAcked1 is UnitTest
  fun name(): String =>
    "watermarking/OriginHighsBelowWithOneToManyFullyAcked1"

  fun ref apply(h: TestHelper) =>
    let o1 = _TestProducer
    let o1route = RouteId(1)
    let o2 = _TestProducer
    let o2route = RouteId(3)
    let t = _OutgoingToIncoming

    t.add(SeqId(1), o1, o1route, SeqId(1))
    // this incoming message is 1 to many
    // in particular (o2, o2route, SeqId(1)) results in 4 outgoing messages
    t.add(SeqId(2), o2, o2route, SeqId(1))
    t.add(SeqId(3), o2, o2route, SeqId(1))
    t.add(SeqId(4), o2, o2route, SeqId(1))
    t.add(SeqId(5), o2, o2route, SeqId(1))

    t.add(SeqId(6), o1, o1route, SeqId(2))
    t.add(SeqId(7), o1, o1route, SeqId(3))
    t.add(SeqId(8), o2, o2route, SeqId(2))
    t.add(SeqId(9), o1, o1route, SeqId(4))

    let index: USize = 4
    try
      h.assert_eq[USize](index, t._index_for(SeqId(5)))
    else
      h.fail()
    end
    let highs = t._origin_highs_below(index)

    h.assert_eq[USize](2, highs.size())
    h.assert_true(highs.contains((o1, o1route)))
    h.assert_true(highs.contains((o2, o2route)))
    try
      h.assert_eq[U64](SeqId(1), highs((o1, o1route)))
      h.assert_eq[U64](SeqId(1), highs((o2, o2route)))
    else
      h.fail()
    end

class iso _TestOriginHighsBelowWithOneToManyFullyAcked2 is UnitTest
  fun name(): String =>
    "watermarking/OriginHighsBelowWithOneToManyFullyAcked2"

  fun ref apply(h: TestHelper) =>
    let o1 = _TestProducer
    let o1route = RouteId(1)
    let o2 = _TestProducer
    let o2route = RouteId(3)
    let t = _OutgoingToIncoming

    t.add(SeqId(1), o1, o1route, SeqId(1))
    // this incoming message is 1 to many
    // in particular (o2, o2route, SeqId(1)) results in 4 outgoing messages
    t.add(SeqId(2), o2, o2route, SeqId(1))
    t.add(SeqId(3), o2, o2route, SeqId(1))
    t.add(SeqId(4), o2, o2route, SeqId(1))
    t.add(SeqId(5), o2, o2route, SeqId(1))

    t.add(SeqId(6), o1, o1route, SeqId(2))
    t.add(SeqId(7), o1, o1route, SeqId(3))
    t.add(SeqId(8), o2, o2route, SeqId(2))
    t.add(SeqId(9), o1, o1route, SeqId(4))

    let index: USize = 7
    try
      h.assert_eq[USize](index, t._index_for(SeqId(8)))
    else
      h.fail()
    end
    let highs = t._origin_highs_below(index)

    h.assert_eq[USize](2, highs.size())
    h.assert_true(highs.contains((o1, o1route)))
    h.assert_true(highs.contains((o2, o2route)))
    try
      h.assert_eq[U64](SeqId(3), highs((o1, o1route)))
      h.assert_eq[U64](SeqId(2), highs((o2, o2route)))
    else
      h.fail()
    end

class iso _TestOriginHighsBelowWithOneToManyFullyAcked3 is UnitTest
  fun name(): String =>
    "watermarking/OriginHighsBelowWithOneToManyFullyAcked3"

  fun ref apply(h: TestHelper) =>
    let o1 = _TestProducer
    let o1route = RouteId(1)
    let o2 = _TestProducer
    let o2route = RouteId(3)
    let t = _OutgoingToIncoming

    t.add(SeqId(1), o1, o1route, SeqId(1))
    // this incoming message is 1 to many
    // in particular (o2, o2route, SeqId(1)) results in 4 outgoing messages
    t.add(SeqId(2), o2, o2route, SeqId(1))
    t.add(SeqId(3), o2, o2route, SeqId(1))
    t.add(SeqId(4), o2, o2route, SeqId(1))
    t.add(SeqId(5), o2, o2route, SeqId(1))

    t.add(SeqId(6), o1, o1route, SeqId(2))
    t.add(SeqId(7), o1, o1route, SeqId(3))
    t.add(SeqId(8), o2, o2route, SeqId(2))
    t.add(SeqId(9), o1, o1route, SeqId(4))

    let index: USize = 6
    try
      h.assert_eq[USize](index, t._index_for(SeqId(7)))
    else
      h.fail()
    end
    let highs = t._origin_highs_below(index)

    h.assert_eq[USize](2, highs.size())
    h.assert_true(highs.contains((o1, o1route)))
    h.assert_true(highs.contains((o2, o2route)))
    try
      h.assert_eq[U64](SeqId(3), highs((o1, o1route)))
      h.assert_eq[U64](SeqId(1), highs((o2, o2route)))
    else
      h.fail()
    end

class iso _TestOutgoingToIncomingEviction is UnitTest
  fun name(): String =>
    "watermarking/OutgoingToIncomingEviction"

  fun ref apply(h: TestHelper) =>
    let o1 = _TestProducer
    let o1route = RouteId(1)
    let o2 = _TestProducer
    let o2route = RouteId(3)
    let t = _OutgoingToIncoming

    t.add(SeqId(1), o1, o1route, SeqId(1))
    t.add(SeqId(2), o2, o2route, SeqId(1))
    t.add(SeqId(3), o1, o1route, SeqId(2))
    t.add(SeqId(4), o1, o1route, SeqId(3))
    t.add(SeqId(5), o2, o2route, SeqId(2))
    t.add(SeqId(6), o1, o1route, SeqId(4))

    let evict_through = SeqId(3)
    let index: USize = 2
    try
      h.assert_eq[USize](index, t._index_for(evict_through))
    else
      h.fail()
    end

    try
      t.evict(evict_through)
      h.assert_eq[USize](3, t.size())
      h.assert_true(t.contains(SeqId(4)))
      h.assert_true(t.contains(SeqId(5)))
      h.assert_true(t.contains(SeqId(6)))
    else
      h.fail()
    end

class iso _TestOutgoingToIncomingBadEviction is UnitTest
  fun name(): String =>
    "watermarking/OutgoingToIncomingBadEviction"

  fun ref apply(h: TestHelper) =>
    let o1 = _TestProducer
    let o1route = RouteId(1)
    let o2 = _TestProducer
    let o2route = RouteId(3)
    let t = _OutgoingToIncoming

    h.assert_eq[USize](0, t.size())

    try
      t.evict(1)
      h.fail()
    end

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

  fun ref _x_resilience_routes(): Routes =>
    Routes

  fun ref _flush(low_watermark: SeqId) =>
    None

  fun ref update_router(router: Router val) =>
    None
