use "sendence/connemara"
use "wallaroo/topology"

actor TestWatermarker is TestList
  new make() =>
    None

  fun tag tests(test: Connemara) =>
    test(_TestProposeWatermarkFullyAcked)
    test(_TestProposeWatermarkFullyAckedFilterLast)
    test(_TestProposeWatermarkOnlyFilter)
    test(_TestProposeWatermarkFullyAckedNoneFiltered)
    test(_TestProposeWatermark1)
    test(_TestProposeWatermark2)
    test(_TestProposeWatermark3)
    test(_TestProposeWatermark4)
    test(_TestProposeWatermark5)

class iso _TestProposeWatermarkFullyAcked is UnitTest
  """
  Test we get the correct proposed watermark when
  all routes are fully acked
  """
  fun name(): String =>
    "watermarker/ProposeWatermarkFullyAcked"

  fun ref apply(h: TestHelper) =>
    let marker: Watermarker = Watermarker
    let route1 = RouteId(1)
    let route2 = RouteId(2)

    marker.add_route(route1)
    marker.add_route(route2)

    marker.filtered(SeqId(1))
    marker.sent(route1, SeqId(2))
    marker.sent(route2, SeqId(3))

    marker.ack_received(route1, SeqId(2))
    marker.ack_received(route2, SeqId(3))

    let proposed = marker.propose_watermark()
    h.assert_eq[U64](3, proposed)

class iso _TestProposeWatermarkFullyAckedFilterLast is UnitTest
  """
  Test we get the correct proposed watermark when
  all routes are fully acked
  """
  fun name(): String =>
    "watermarker/ProposeWatermarkFullyAckedFilterLast"

  fun ref apply(h: TestHelper) =>
    let marker: Watermarker = Watermarker
    let route1 = RouteId(1)
    let route2 = RouteId(2)

    marker.add_route(route1)
    marker.add_route(route2)

    marker.sent(route1, SeqId(1))
    marker.sent(route2, SeqId(2))
    marker.filtered(SeqId(3))
    marker.filtered(SeqId(4))

    marker.ack_received(route1, SeqId(1))
    marker.ack_received(route2, SeqId(2))

    let proposed = marker.propose_watermark()
    h.assert_eq[U64](4, proposed)

class iso _TestProposeWatermarkOnlyFilter is UnitTest
  """
  Test we get the correct proposed watermark when
  all routes are fully acked
  """
  fun name(): String =>
    "watermarker/ProposeWatermarkOnlyFilter"

  fun ref apply(h: TestHelper) =>
    let marker: Watermarker = Watermarker
    let route1 = RouteId(1)
    let route2 = RouteId(2)

    marker.add_route(route1)
    marker.add_route(route2)

    marker.filtered(SeqId(3))
    marker.filtered(SeqId(4))

    let proposed: U64 = marker.propose_watermark()
    h.assert_eq[U64](4, proposed)

class iso _TestProposeWatermarkFullyAckedNoneFiltered is UnitTest
  """
  Test we get the correct proposed watermark when
  all routes are fully acked and none were filtered
  """
  fun name(): String =>
    "watermarker/ProposeWatermarkFullyAckedNoneFiltered"

  fun ref apply(h: TestHelper) =>
    let marker: Watermarker = Watermarker
    let route1 = RouteId(1)
    let route2 = RouteId(2)

    marker.add_route(route1)
    marker.add_route(route2)

    marker.sent(route1, SeqId(2))
    marker.sent(route2, SeqId(3))

    marker.ack_received(route1, SeqId(2))
    marker.ack_received(route2, SeqId(3))

    let proposed: U64 = marker.propose_watermark()
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
    "watermarker/ProposeWatermark1"

  fun ref apply(h: TestHelper) =>
    let marker: Watermarker = Watermarker
    let route1 = RouteId(1)
    let route2 = RouteId(2)
    let route3 = RouteId(3)

    marker.add_route(route1)
    marker.add_route(route2)
    marker.add_route(route3)

    marker.sent(route1, SeqId(1))
    marker.sent(route1, SeqId(2))
    marker.ack_received(route1, SeqId(1))

    marker.sent(route2, SeqId(5))
    marker.ack_received(route2, SeqId(5))

    marker.sent(route3, SeqId(4))
    marker.sent(route3, SeqId(6))
    marker.sent(route3, SeqId(7))
    marker.ack_received(route3, SeqId(4))

    let proposed: U64 = marker.propose_watermark()
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
    "watermarker/ProposeWatermark2"

  fun ref apply(h: TestHelper) =>
    let marker: Watermarker = Watermarker
    let route1 = RouteId(1)
    let route2 = RouteId(2)
    let route3 = RouteId(3)

    marker.add_route(route1)
    marker.add_route(route2)
    marker.add_route(route3)

    marker.sent(route1, SeqId(1))
    marker.sent(route1, SeqId(2))
    marker.sent(route1, SeqId(3))
    marker.ack_received(route1, SeqId(1))

    marker.sent(route2, SeqId(5))
    marker.ack_received(route2, SeqId(5))

    marker.sent(route3, SeqId(4))
    marker.sent(route3, SeqId(6))
    marker.sent(route3, SeqId(7))
    marker.ack_received(route3, SeqId(4))

    let proposed: U64 = marker.propose_watermark()
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
    "watermarker/ProposeWatermark3"

  fun ref apply(h: TestHelper) =>
    let marker: Watermarker = Watermarker
    let route1 = RouteId(1)
    let route2 = RouteId(2)
    let route3 = RouteId(3)

    marker.add_route(route1)
    marker.add_route(route2)
    marker.add_route(route3)

    marker.sent(route1, SeqId(1))
    marker.sent(route1, SeqId(3))
    marker.sent(route1, SeqId(8))
    marker.sent(route1, SeqId(9))
    marker.ack_received(route1, SeqId(1))

    marker.sent(route2, SeqId(5))
    marker.ack_received(route2, SeqId(5))

    marker.sent(route3, SeqId(4))
    marker.sent(route3, SeqId(6))
    marker.sent(route3, SeqId(7))
    marker.ack_received(route3, SeqId(4))

    let proposed: U64 = marker.propose_watermark()
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
    "watermarker/ProposeWatermark4"

  fun ref apply(h: TestHelper) =>
    let marker: Watermarker = Watermarker
    let route1 = RouteId(1)
    let route2 = RouteId(2)
    let route3 = RouteId(3)

    marker.add_route(route1)
    marker.add_route(route2)
    marker.add_route(route3)

    marker.filtered(SeqId(7))

    marker.sent(route1, SeqId(3))
    marker.sent(route1, SeqId(8))
    marker.sent(route1, SeqId(9))
    marker.ack_received(route1, SeqId(3))

    marker.sent(route2, SeqId(5))
    marker.ack_received(route2, SeqId(5))

    let proposed: U64 = marker.propose_watermark()
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
    "watermarker/ProposeWatermark5"

  fun ref apply(h: TestHelper) =>
    let marker: Watermarker = Watermarker
    let route1 = RouteId(1)
    let route2 = RouteId(2)
    let route3 = RouteId(3)

    marker.add_route(route1)
    marker.add_route(route2)
    marker.add_route(route3)

    marker.filtered(SeqId(7))

    marker.sent(route1, SeqId(3))
    marker.sent(route1, SeqId(8))
    marker.sent(route1, SeqId(9))
    marker.ack_received(route1, SeqId(3))

    marker.sent(route2, SeqId(5))
    marker.ack_received(route2, SeqId(5))

    marker.sent(route3, SeqId(1))

    let proposed: U64 = marker.propose_watermark()
    h.assert_eq[U64](0, proposed)
