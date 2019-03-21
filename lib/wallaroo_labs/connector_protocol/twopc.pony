/*

Copyright 2019 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

use "buffered"

type TwoPCFsmState is (TwoPCFsmStart |
  TwoPCFsm1Precommit |
  TwoPCFsm2Commit |
  TwoPCFsm2CommitFast |
  TwoPCFsm2Abort)

primitive TwoPCFsmStart
  fun apply(): U8 => 0
primitive TwoPCFsm1Precommit
  fun apply(): U8 => 1
primitive TwoPCFsm2Commit
  fun apply(): U8 => 2
primitive TwoPCFsm2CommitFast
  fun apply(): U8 => 3
primitive TwoPCFsm2Abort
  fun apply(): U8 => 4

primitive TwoPCEncode
  fun list_uncommitted(rtag: U64): Array[U8] val =>
    let wb: Writer = wb.create()
    let m = ListUncommittedMsg(rtag)
    TwoPCFrame.encode(m, wb)

  fun phase1(txn_id: String, where_list: WhereList): Array[U8] val =>
    let wb: Writer = wb.create()
    let m = TwoPCPhase1Msg(txn_id, where_list)
    TwoPCFrame.encode(m, wb)

  fun phase2(txn_id: String, commit: Bool): Array[U8] val =>
    let wb: Writer = wb.create()
    let m = TwoPCPhase2Msg(txn_id, commit)
    TwoPCFrame.encode(m, wb)

