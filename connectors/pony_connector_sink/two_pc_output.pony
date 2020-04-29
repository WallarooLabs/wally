use cwm = "wallaroo_labs/connector_wire_messages"

trait TwoPCOutput
  fun ref open(instance_name: cwm.WorkerName): cwm.PointOfRef
  fun truncate_and_seek_to(truncate_offset: cwm.PointOfRef): cwm.PointOfRef
  fun out_tell(): cwm.PointOfRef
  fun flush_fsync_all()
  fun flush_fsync_out()
  fun flush_fsync_txn_log()
  fun ref append_output(msg: Array[U8] val): (U64, cwm.PointOfRef)?
  fun append_txn_log(log_entry: (U64, TxnLogItem))
  fun read_txn_log_lines(): Array[TxnLogItem]
  fun leaving_workers(leaving_workers': Seq[cwm.WorkerName] box)

class TwoPCOutputInMemory is TwoPCOutput
  let _out_path: String
  var _instance_name: cwm.WorkerName
  let _output: Array[U8]
  let _txn_log: Array[(U64, TxnLogItem)]

  new create(out_path: String) =>
    _out_path = out_path
    _instance_name = ""
    _output = _output.create()
    _txn_log = _txn_log.create()

  fun ref open(instance_name: cwm.WorkerName): cwm.PointOfRef =>
    // TODO: implement this
    _instance_name = instance_name
    0

  fun truncate_and_seek_to(truncate_offset: cwm.PointOfRef): cwm.PointOfRef =>
    // TODO: implement this
    0

  fun out_tell(): cwm.PointOfRef =>
    // TODO: implement this
    0

  fun flush_fsync_all() =>
    // TODO: implement this
    None

  fun flush_fsync_out() =>
    // TODO: implement this
    None

  fun flush_fsync_txn_log() =>
    // TODO: implement this
    None

  fun ref append_output(msg: Array[U8] val): (U64, cwm.PointOfRef) =>
    _output.concat(msg.values())

    (msg.size().u64(), _output.size().u64())

  fun append_txn_log(log_entry: (U64, TxnLogItem)) =>
    (let timestamp, let txn_log_item) = log_entry


  fun read_txn_log_lines(): Array[TxnLogItem] =>
    // TODO: implement this
    []

  fun leaving_workers(leaving_workers': Seq[cwm.WorkerName] box) =>
    """
    def leaving_workers(self, leaving_workers):
        for w in leaving_workers:
            opath = self._out_path + "." + w
            mv_path1 = "{}.{}".format(opath, time.time())
            cmd1 = "mv {} {} > /dev/null 2>&1".format(opath, mv_path1)
            cmd2 = "mv {}.txnlog {}.txnlog > /dev/null 2>&1".format(opath, mv_path1)
            logging.info("leaving worker: run: {}".format(cmd1))
            logging.info("leaving worker: run: {}".format(cmd2))
            os.system(cmd1)
            os.system(cmd2)
    """
    // TODO: implement this
    None
