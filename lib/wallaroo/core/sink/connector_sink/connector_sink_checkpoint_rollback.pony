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

use "wallaroo/core/sink"
use cwm = "wallaroo_labs/connector_wire_messages"
use "wallaroo_labs/logging"
use "wallaroo_labs/mort"

/****
Boilerplate: sed -n '/BEGIN LEFT/,/END LEFT/p' connector-sink-2pc-management.dot | grep label | grep -e '->' | sed -e 's:.*label="::' -e 's:".*::' -e 's:\\n.*::g' | sed 's/://' | sort -u | awk 'BEGIN {print "trait _CpRbOps\n  fun name(): String\n";} {printf("  fun ref %s(sink: ConnectorSink ref):\n    _CpRbOps ref\n  =>\n    _invalid_call(__loc.method_name()); Fail(); this\n\n", $1); }'
Missing: enter()
****/

trait _CpRbOps
  fun name(): String

  fun ref abort_next_checkpoint(sink: ConnectorSink ref):
    _CpRbOps ref
  =>
    _invalid_call(__loc.method_name()); Fail(); this

  fun ref checkpoint_complete(sink: ConnectorSink ref):
    _CpRbOps ref
  =>
    _invalid_call(__loc.method_name()); Fail(); this

  fun ref conn_ready(sink: ConnectorSink ref):
    _CpRbOps ref
  =>
    _invalid_call(__loc.method_name()); Fail(); this

  fun ref cp_barrier_complete(sink: ConnectorSink ref):
    _CpRbOps ref
  =>
    _invalid_call(__loc.method_name()); Fail(); this

  fun ref enter(sink: ConnectorSink ref) =>
    None

  fun ref phase1_abort(sink: ConnectorSink ref):
    _CpRbOps ref
  =>
    _invalid_call(__loc.method_name()); Fail(); this

  fun ref phase1_commit(sink: ConnectorSink ref):
    _CpRbOps ref
  =>
    _invalid_call(__loc.method_name()); Fail(); this

  fun ref prepare_for_rollback(sink: ConnectorSink ref):
    _CpRbOps ref
  =>
    _invalid_call(__loc.method_name()); Fail(); this

  fun ref rollback(sink: ConnectorSink ref):
    _CpRbOps ref
  =>
    _invalid_call(__loc.method_name()); Fail(); this

  fun ref rollbackresume_barrier_complete(sink: ConnectorSink ref):
    _CpRbOps ref
  =>
    _invalid_call(__loc.method_name()); Fail(); this

  fun _invalid_call(method_name: String) =>
    @l(Log.crit(), Log.conn_sink(),
      "Invalid call to %s on _CpRbOps state %s".cstring(),
      method_name.cstring(), name().cstring())

primitive _CpRbTransition
  fun apply(curr: _CpRbOps, next: _CpRbOps, sink: ConnectorSink ref)
    : _CpRbOps
  =>
    @l(Log.debug(), Log.conn_sink(),
      "CpRbTransition:: %s -> %s".cstring(),
      curr.name().cstring(), next.name().cstring())
    next.enter(sink)
    next

/****
Boilerplate: sed -n '/BEGIN LEFT/,/END LEFT/p' connector-sink-2pc-management.dot | grep -e '->' | awk '{print $1}' | sort -u | grep -v START | awk '{ printf("class _CpRb%s is _CpRbOps\n  fun name(): String => __loc.type_name()\n\n", $1); }'
****/

class _CpRbAbortCheckpoint is _CpRbOps
  fun name(): String => __loc.type_name()

class _CpRbCPGotLocalVote is _CpRbOps
  fun name(): String => __loc.type_name()

class _CpRbCPStarts is _CpRbOps
  fun name(): String => __loc.type_name()

class _CpRbInit is _CpRbOps
  fun name(): String => __loc.type_name()

  fun ref enter(sink: ConnectorSink ref) =>
    let empty = Array[SinkPhaseQueued]
    sink.swap_barrier_to_queued(empty)

  fun ref conn_read(sink: ConnectorSink ref): _CpRbOps =>
    _CpRbTransition(this, _CpRbWaitingForCheckpoint, sink)

class _CpRbPreparedForRollback is _CpRbOps
  fun name(): String => __loc.type_name()

class _CpRbRolledBack is _CpRbOps
  fun name(): String => __loc.type_name()

class _CpRbRollingBack is _CpRbOps
  fun name(): String => __loc.type_name()

class _CpRbWaitingForCheckpoint is _CpRbOps
  fun name(): String => __loc.type_name()

  fun ref enter(sink: ConnectorSink ref) =>
    sink._resume_processing_messages()

