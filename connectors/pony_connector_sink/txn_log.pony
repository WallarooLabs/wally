use cwm = "wallaroo_labs/connector_wire_messages"

trait val TxnLogItem

class Orphaned is TxnLogItem
  let txn_id: String
  let start_point_of_ref: cwm.PointOfRef
  let end_point_of_ref: cwm.PointOfRef

  new val create(txn_id': String, start': cwm.PointOfRef, end': cwm.PointOfRef) =>
    txn_id = txn_id'
    start_point_of_ref = start'
    end_point_of_ref = end'

class ListUncommitted is TxnLogItem
  let txn_id: String
  let uncommitted: Array[String] val

  new val create(txn_id': String, uncommitted': Array[String] val) =>
    txn_id = txn_id'
    uncommitted = uncommitted'

class NextTxnForceAbort is TxnLogItem
  let message: String

  new val create(message': String) =>
    message = message'

class PhaseOneRollback is TxnLogItem
  let txn_id: String
  let where_list: cwm.WhereList val

  new val create(txn_id': String, where_list': cwm.WhereList val) =>
    txn_id = txn_id'
    where_list = where_list'

class PhaseOneOk is TxnLogItem
  let txn_id: String
  let where_list: cwm.WhereList val

  new val create(txn_id': String, where_list': cwm.WhereList val) =>
    txn_id = txn_id'
    where_list = where_list'

class PhaseTwoRollback is TxnLogItem
  let txn_id: String
  let offset: cwm.PointOfRef

  new val create(txn_id': String, offset': cwm.PointOfRef) =>
    txn_id = txn_id'
    offset = offset'

class PhaseTwoOk is TxnLogItem
  let txn_id: String
  let offset: cwm.PointOfRef

  new val create(txn_id': String, offset': cwm.PointOfRef) =>
    txn_id = txn_id'
    offset = offset'

class PhaseTwoError is TxnLogItem
  let txn_id: String
  let message: String

  new val create(txn_id': String, message': String) =>
    txn_id = txn_id'
    message = message'

class WorkersLeft is TxnLogItem
  let txn_id: String
  let workers: Array[String] val

  new val create(txn_id': String, workers': Array[String] val) =>
    txn_id = txn_id'
    workers = workers'

class ConnectoinClosed is TxnLogItem
  let txn_id: String

  new val create(txn_id': String) =>
    txn_id = txn_id'
