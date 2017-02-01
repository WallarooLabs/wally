use "ponytest"

use "wallaroo/topology"

actor TestWatermarking is TestList
  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    test(_TestProposeWatermarkFullyAcked)
    test(_TestProposeWatermarkFullyAckedFilterLast)
    test(_TestProposeWatermarkOnlyFilter)
    test(_TestProposeWatermarkFullyAckedNoneFiltered)
    test(_TestProposeWatermark1)
    test(_TestProposeWatermark2)
    test(_TestProposeWatermark3)
    test(_TestProposeWatermark4)
    test(_TestProposeWatermark5)
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
    test(_TestOutgoingToIncomingEviction)
    test(_TestOutgoingToIncomingBadEviction)

class iso _TestProposeWatermarkFullyAcked is UnitTest
  """
  Test we get the correct proposed watermark when
  all routes are fully acked
  """
  fun name(): String =>
    "resilience/ProposeWatermarkFullyAcked"

  fun ref apply(h: TestHelper) =>
    let filter_route: _FilterRoute ref  = recover ref _FilterRoute end
    let route1: _Route ref = recover ref _Route end
    let route2: _Route ref = recover ref _Route end

    filter_route.filter(SeqId(1))
    route1.send(SeqId(2))
    route2.send(SeqId(3))

    route1.receive_ack(SeqId(2))
    route2.receive_ack(SeqId(3))

    let routes = [route1, route2]
    let proposed: U64 = _ProposeWatermark(filter_route, routes)
    h.assert_eq[U64](3, proposed)

class iso _TestProposeWatermarkFullyAckedFilterLast is UnitTest
  """
  Test we get the correct proposed watermark when
  all routes are fully acked
  """
  fun name(): String =>
    "resilience/ProposeWatermarkFullyAckedFilterLast"

  fun ref apply(h: TestHelper) =>
    let filter_route: _FilterRoute ref  = recover ref _FilterRoute end
    let route1: _Route ref = recover ref _Route end
    let route2: _Route ref = recover ref _Route end

    route1.send(SeqId(1))
    route2.send(SeqId(2))
    filter_route.filter(SeqId(3))
    filter_route.filter(SeqId(4))

    route1.receive_ack(SeqId(1))
    route2.receive_ack(SeqId(2))

    let routes = [route1, route2]
    let proposed: U64 = _ProposeWatermark(filter_route, routes)
    h.assert_eq[U64](4, proposed)

class iso _TestProposeWatermarkOnlyFilter is UnitTest
  """
  Test we get the correct proposed watermark when
  all routes are fully acked
  """
  fun name(): String =>
    "resilience/ProposeWatermarkOnlyFilter"

  fun ref apply(h: TestHelper) =>
    let filter_route: _FilterRoute ref  = recover ref _FilterRoute end
    let route1: _Route ref = recover ref _Route end
    let route2: _Route ref = recover ref _Route end

    filter_route.filter(SeqId(3))
    filter_route.filter(SeqId(4))

    let routes = [route1, route2]
    let proposed: U64 = _ProposeWatermark(filter_route, routes)
    h.assert_eq[U64](4, proposed)

class iso _TestProposeWatermarkFullyAckedNoneFiltered is UnitTest
  """
  Test we get the correct proposed watermark when
  all routes are fully acked and none were filtered
  """
  fun name(): String =>
    "resilience/ProposeWatermarkFullyAckedNoneFiltered"

  fun ref apply(h: TestHelper) =>
    let filter_route: _FilterRoute ref  = recover ref _FilterRoute end
    let route1: _Route ref = recover ref _Route end
    let route2: _Route ref = recover ref _Route end

    route1.send(SeqId(2))
    route2.send(SeqId(3))

    route1.receive_ack(SeqId(2))
    route2.receive_ack(SeqId(3))

    let routes = [route1, route2]
    let proposed: U64 = _ProposeWatermark(filter_route, routes)
    h.assert_eq[U64](3, proposed)

class iso _TestProposeWatermark1 is UnitTest
  """
  Route | Sent | Ack
  A       0     0
  B       2     1
  C       5     5
  D       7     4

  Should be 1
  """
  fun name(): String =>
    "resilience/ProposeWatermark1"

  fun ref apply(h: TestHelper) =>
    let filter_route: _FilterRoute ref  = recover ref _FilterRoute end
    let route1: _Route ref = recover ref _Route end
    let route2: _Route ref = recover ref _Route end
    let route3: _Route ref = recover ref _Route end

    route1.send(SeqId(1))
    route1.send(SeqId(2))
    route1.receive_ack(SeqId(1))

    route2.send(SeqId(5))
    route2.receive_ack(SeqId(5))

    route3.send(SeqId(4))
    route3.send(SeqId(6))
    route3.send(SeqId(7))
    route3.receive_ack(SeqId(4))

    let routes = [route1, route2, route3]
    let proposed: U64 = _ProposeWatermark(filter_route, routes)
    h.assert_eq[U64](1, proposed)

class iso _TestProposeWatermark2 is UnitTest
  """
  Route | Sent | Ack
    A       0     0
    B       3     1
    C       5     5
    D       7     4

  Should be 1
  """
  fun name(): String =>
    "resilience/ProposeWatermark2"

  fun ref apply(h: TestHelper) =>
    let filter_route: _FilterRoute ref  = recover ref _FilterRoute end
    let route1: _Route ref = recover ref _Route end
    let route2: _Route ref = recover ref _Route end
    let route3: _Route ref = recover ref _Route end

    route1.send(SeqId(1))
    route1.send(SeqId(2))
    route1.send(SeqId(3))
    route1.receive_ack(SeqId(1))

    route2.send(SeqId(5))
    route2.receive_ack(SeqId(5))

    route3.send(SeqId(4))
    route3.send(SeqId(6))
    route3.send(SeqId(7))
    route3.receive_ack(SeqId(4))

    let routes = [route1, route2, route3]
    let proposed: U64 = _ProposeWatermark(filter_route, routes)
    h.assert_eq[U64](1, proposed)

class iso _TestProposeWatermark3 is UnitTest
  """
  Route | Sent | Ack
    A       0     0
    B       9     1
    C       5     5
    D       7     4

  Should be 1
  """
  fun name(): String =>
    "resilience/ProposeWatermark3"

  fun ref apply(h: TestHelper) =>
    let filter_route: _FilterRoute ref  = recover ref _FilterRoute end
    let route1: _Route ref = recover ref _Route end
    let route2: _Route ref = recover ref _Route end
    let route3: _Route ref = recover ref _Route end

    route1.send(SeqId(1))
    route1.send(SeqId(3))
    route1.send(SeqId(8))
    route1.send(SeqId(9))
    route1.receive_ack(SeqId(1))

    route2.send(SeqId(5))
    route2.receive_ack(SeqId(5))

    route3.send(SeqId(4))
    route3.send(SeqId(6))
    route3.send(SeqId(7))
    route3.receive_ack(SeqId(4))

    let routes = [route1, route2, route3]
    let proposed: U64 = _ProposeWatermark(filter_route, routes)
    h.assert_eq[U64](1, proposed)

class iso _TestProposeWatermark4 is UnitTest
  """
  Route | Sent | Ack
    A       7     7
    B       9     3
    C       5     5
    D       0     0

  Should be 3
  """
  fun name(): String =>
    "resilience/ProposeWatermark4"

  fun ref apply(h: TestHelper) =>
    let filter_route: _FilterRoute ref  = recover ref _FilterRoute end
    let route1: _Route ref = recover ref _Route end
    let route2: _Route ref = recover ref _Route end
    let route3: _Route ref = recover ref _Route end

    filter_route.filter(SeqId(7))

    route1.send(SeqId(3))
    route1.send(SeqId(8))
    route1.send(SeqId(9))
    route1.receive_ack(SeqId(3))

    route2.send(SeqId(5))
    route2.receive_ack(SeqId(5))

    let routes = [route1, route2, route3]
    let proposed: U64 = _ProposeWatermark(filter_route, routes)
    h.assert_eq[U64](3, proposed)

class iso _TestProposeWatermark5 is UnitTest
  """
  Route | Sent | Ack
    A       7     7
    B       9     3
    C       5     5
    D       1     0

  Should be 0
  """
  fun name(): String =>
    "resilience/ProposeWatermark5"

  fun ref apply(h: TestHelper) =>
    let filter_route: _FilterRoute ref  = recover ref _FilterRoute end
    let route1: _Route ref = recover ref _Route end
    let route2: _Route ref = recover ref _Route end
    let route3: _Route ref = recover ref _Route end

    filter_route.filter(SeqId(7))

    route1.send(SeqId(3))
    route1.send(SeqId(8))
    route1.send(SeqId(9))
    route1.receive_ack(SeqId(3))

    route2.send(SeqId(5))
    route2.receive_ack(SeqId(5))

    route3.send(SeqId(1))

    let routes = [route1, route2, route3]
    let proposed: U64 = _ProposeWatermark(filter_route, routes)
    h.assert_eq[U64](0, proposed)

///
///
class iso _TestDataReceiverProposeWatermarkFullyAcked is UnitTest
  """
  Test we get the correct proposed watermark when
  all routes are fully acked
  """
  fun name(): String =>
    "resilience/DataReceiverProposeWatermarkFullyAcked"

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
    "resilience/DataReceiverProposeWatermark1"

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
    "resilience/DataReceiverProposeWatermark2"

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
    "resilience/DataReceiverProposeWatermark3"

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
    "resilience/DataReceiverProposeWatermark4"

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
    "resilience/DataReceiverProposeWatermark5"

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
    "resilience/_TestOutgoingToIncomingEmptyIndexFor"

  fun ref apply(h: TestHelper) =>
    let t = _OutgoingToIncoming

    try
      t._index_for(1)
      h.fail()
    end

class iso _TestOutgoingToIncomingIndexFor1 is UnitTest
  fun name(): String =>
    "resilience/_TestOutgoingToIncomingIndexFor1"

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
    "resilience/_TestOutgoingToIncomingIndexFor2"

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
    "resilience/_TestOriginHighsBelow1"

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
    "resilience/_TestOriginHighsBelow2"

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

class iso _TestOutgoingToIncomingEviction is UnitTest
  fun name(): String =>
    "resilience/_TestOutgoingToIncomingEviction"

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
    "resilience/_TestOutgoingToIncomingBadEviction"

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
  be receive_credits(credits: ISize, from: CreditFlowConsumer) =>
    None

  be mute(c: CreditFlowConsumer) =>
    None

  be unmute(c: CreditFlowConsumer) =>
    None

  fun ref recoup_credits(credits: ISize) =>
    None

  fun ref route_to(c: CreditFlowConsumer): (Route | None) =>
    None

  fun ref next_sequence_id(): U64 =>
    0

  fun ref current_sequence_id(): U64 =>
    0

  fun ref _x_resilience_routes(): Routes =>
    Routes

  fun ref _flush(low_watermark: SeqId) =>
    None
