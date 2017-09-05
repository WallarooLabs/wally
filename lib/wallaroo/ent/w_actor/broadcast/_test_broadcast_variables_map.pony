/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use "collections"
use "sendence/connemara"

actor _TestExternalBroadcastVariableUpdater is TestList
  new make() =>
    None

  fun tag tests(test: Connemara) =>
    test(_TestExternalUpdateDecision)

class iso _TestExternalUpdateDecision is UnitTest
  """
  Test that broadcast variable external updates only result in updates
  under the appropriate conditions
  """
  fun name(): String =>
    "broadcast_variables_map/ExternalUpdateDecision"

  fun ref apply(h: TestHelper) ? =>
    // Incomparable timestamps mean we go by lexicographic ordering of
    // worker names.  In this case, the source of the external update
    // has a lower name, so we don't update.
    let cur_ts1_map = recover trn Map[String, U64] end
    cur_ts1_map("w1") = 0
    cur_ts1_map("w2") = 2
    cur_ts1_map("w3") = 1
    let cur_ts1 = VectorTimestamp("w2", consume cur_ts1_map)
    let map1 = Map[String, (VectorTimestamp, Any val)]
    map1("k1") = (cur_ts1, U64(0))
    map1("k2") = (cur_ts1, U64(0))
    map1("k4") = (cur_ts1, U64(0))
    let ext_ts1_map = recover trn Map[String, U64] end
    ext_ts1_map("w1") = 0
    ext_ts1_map("w2") = 2
    ext_ts1_map("w3") = 1
    let ext_ts1 = VectorTimestamp("w1", consume ext_ts1_map)
    let res1 = _ExternalBroadcastVariableUpdater(map1, "k1", U64(10), ext_ts1,
      "w1", "w2")
    h.assert_eq[Bool](false, res1)

    // Incomparable timestamps mean we go by lexicographic ordering of
    // worker names.  In this case, the source of the external update
    // has a higher name, so we do update.
    let cur_ts2_map = recover trn Map[String, U64] end
    cur_ts2_map("w1") = 0
    cur_ts2_map("w2") = 2
    cur_ts2_map("w3") = 1
    let cur_ts2 = VectorTimestamp("w1", consume cur_ts2_map)
    let map2 = Map[String, (VectorTimestamp, Any val)]
    map2("k1") = (cur_ts2, U64(0))
    map2("k2") = (cur_ts2, U64(0))
    map1("k4") = (cur_ts2, U64(0))
    let ext_ts2_map = recover trn Map[String, U64] end
    ext_ts2_map("w1") = 0
    ext_ts2_map("w2") = 3
    ext_ts2_map("w4") = 1
    let ext_ts2 = VectorTimestamp("w2", consume ext_ts2_map)
    let res2 = _ExternalBroadcastVariableUpdater(map2, "k1", U64(10),
      ext_ts2, "w2", "w1")
    h.assert_eq[Bool](true, res2)

    // If timestamps are comparable and the source of the external update
    // is greater, then update.
    let cur_ts3_map = recover trn Map[String, U64] end
    cur_ts3_map("w1") = 0
    cur_ts3_map("w2") = 2
    cur_ts3_map("w3") = 1
    let cur_ts3 = VectorTimestamp("w1", consume cur_ts3_map)
    let map3 = Map[String, (VectorTimestamp, Any val)]
    map3("k1") = (cur_ts3, U64(0))
    map3("k2") = (cur_ts3, U64(0))
    let ext_ts3_map = recover trn Map[String, U64] end
    ext_ts3_map("w1") = 1
    ext_ts3_map("w2") = 2
    ext_ts3_map("w3") = 2
    let ext_ts3 = VectorTimestamp("w2", consume ext_ts3_map)
    let res3 = _ExternalBroadcastVariableUpdater(map3, "k1", U64(10),
      ext_ts3, "w1", "w2")
    h.assert_eq[Bool](true, res3)

    // If timestamps are comparable and the source of the external update
    // is <, then do not update.
    let cur_ts4_map = recover trn Map[String, U64] end
    cur_ts4_map("w1") = 3
    cur_ts4_map("w2") = 2
    cur_ts4_map("w3") = 4
    let cur_ts4 = VectorTimestamp("w1", consume cur_ts4_map)
    let map4 = Map[String, (VectorTimestamp, Any val)]
    map4("k1") = (cur_ts4, U64(0))
    map4("k2") = (cur_ts4, U64(0))
    let ext_ts4_map = recover trn Map[String, U64] end
    ext_ts4_map("w1") = 1
    ext_ts4_map("w2") = 1
    ext_ts4_map("w3") = 1
    let ext_ts4 = VectorTimestamp("w2", consume ext_ts4_map)
    let res4 = _ExternalBroadcastVariableUpdater(map4, "k1", U64(10),
      ext_ts4, "w1", "w2")
    h.assert_eq[Bool](true, ext_ts4 < cur_ts4)
    h.assert_eq[Bool](false, res4)

    // If timestamps are comparable and the source of the external update
    // is ==, then do not update.
    let cur_ts5_map = recover trn Map[String, U64] end
    cur_ts5_map("w1") = 1
    cur_ts5_map("w2") = 1
    cur_ts5_map("w3") = 1
    let cur_ts5 = VectorTimestamp("w1", consume cur_ts5_map)
    let map5 = Map[String, (VectorTimestamp, Any val)]
    map5("k1") = (cur_ts5, U64(0))
    map5("k2") = (cur_ts5, U64(0))
    let ext_ts5_map = recover trn Map[String, U64] end
    ext_ts5_map("w1") = 1
    ext_ts5_map("w2") = 1
    ext_ts5_map("w3") = 1
    let ext_ts5 = VectorTimestamp("w2", consume ext_ts5_map)
    let res5 = _ExternalBroadcastVariableUpdater(map5, "k1", U64(10),
      ext_ts5, "w1", "w2")
    h.assert_eq[Bool](true, (cur_ts5 >= ext_ts5) and (cur_ts5 <= ext_ts5))
    h.assert_eq[Bool](false, res5)
