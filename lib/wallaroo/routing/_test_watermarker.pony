use "sendence/connemara"
use "wallaroo/topology"

actor TestWatermarker is TestList
  new make() =>
    None

  fun tag tests(test: Connemara) =>
    test(_TestProposeWatermarkFullyAckedFoo)
    test(_TestProposeWatermarkFullyAckedFilterLastFoo)
    test(_TestProposeWatermarkOnlyFilterFoo)
    test(_TestProposeWatermarkFullyAckedNoneFilteredFoo)
    test(_TestProposeWatermark1Foo)
    test(_TestProposeWatermark2Foo)
    test(_TestProposeWatermark3Foo)
    test(_TestProposeWatermark4Foo)
    test(_TestProposeWatermark5Foo)

class iso _TestProposeWatermarkFullyAckedFoo is UnitTest
  """
  Test we get the correct proposed watermark when
  all routes are fully acked
  """
  fun name(): String =>
    "watermarker/ProposeWatermarkFullyAckedFoo"

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

class iso _TestProposeWatermarkFullyAckedFilterLastFoo is UnitTest
  """
  Test we get the correct proposed watermark when
  all routes are fully acked
  """
  fun name(): String =>
    "watermarking/ProposeWatermarkFullyAckedFilterLastFoo"

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

class iso _TestProposeWatermarkOnlyFilterFoo is UnitTest
  """
  Test we get the correct proposed watermark when
  all routes are fully acked
  """
  fun name(): String =>
    "watermarking/ProposeWatermarkOnlyFilterFoo"

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

class iso _TestProposeWatermarkFullyAckedNoneFilteredFoo is UnitTest
  """
  Test we get the correct proposed watermark when
  all routes are fully acked and none were filtered
  """
  fun name(): String =>
    "watermarking/ProposeWatermarkFullyAckedNoneFilteredFoo"

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

class iso _TestProposeWatermark1Foo is UnitTest
  """
  Route | Sent | Ack
  A       0     0
  B       2     1
  C       5     5
  D       7     4

  Should be 1
  """
  fun name(): String =>
    "watermarking/ProposeWatermark1Foo"

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

class iso _TestProposeWatermark2Foo is UnitTest
  """
  Route | Sent | Ack
    A       0     0
    B       3     1
    C       5     5
    D       7     4

  Should be 1
  """
  fun name(): String =>
    "watermarking/ProposeWatermark2Foo"

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

class iso _TestProposeWatermark3Foo is UnitTest
  """
  Route | Sent | Ack
    A       0     0
    B       9     1
    C       5     5
    D       7     4

  Should be 1
  """
  fun name(): String =>
    "watermarking/ProposeWatermark3Foo"

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

class iso _TestProposeWatermark4Foo is UnitTest
  """
  Route | Sent | Ack
    A       7     7
    B       9     3
    C       5     5
    D       0     0

  Should be 3
  """
  fun name(): String =>
    "watermarking/ProposeWatermark4Foo"

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

class iso _TestProposeWatermark5Foo is UnitTest
  """
  Route | Sent | Ack
    A       7     7
    B       9     3
    C       5     5
    D       1     0

  Should be 0
  """
  fun name(): String =>
    "watermarking/ProposeWatermark5Foo"

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
