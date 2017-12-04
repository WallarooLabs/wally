use "collections"
use "wallaroo/core/common"


primitive StatelessPartition
  fun pre_stateless_data(pipeline_name: String, partition_id: StepId,
    workers: Array[String] val, threads_per_worker: USize): PreStatelessData ?
  =>
    let step_id_gen = StepIdGenerator

    // First we calculate the size of the partition and determine
    // where the steps in the partition go in the cluster. We are
    // populating three maps. Two of them, partition_id_to_worker
    // and partition_id_to_step_id, will be used to create a
    // StatelessPartitionRouter during local topology
    // initialization. The third, worker_to_step_id, will be used
    // here to determine which step ids we will put in which
    // local graphs.
    let ws = Array[String]
    for w in workers.values() do ws.push(w) end
    let sorted_workers = Sort[Array[String], String](ws)
    let worker_count = workers.size()
    let partition_count = worker_count * threads_per_worker
    let partition_id_to_worker_trn =
      recover trn Map[U64, String] end
    let partition_id_to_step_id_trn =
      recover trn Map[U64, U128] end
    let worker_to_step_id_trn =
      recover trn Map[String, Array[U128] trn] end
    for w in sorted_workers.values() do
      worker_to_step_id_trn(w) = recover Array[U128] end
    end
    for id in Range[U64](0, partition_count.u64()) do
      let step_id = step_id_gen()
      partition_id_to_step_id_trn(id) = step_id
      let w = sorted_workers(id.usize() % worker_count)?
      partition_id_to_worker_trn(id) = w
      worker_to_step_id_trn(w)?.push(step_id)
    end
    let partition_id_to_worker: Map[U64, String] val =
      consume partition_id_to_worker_trn
    let partition_id_to_step_id: Map[U64, U128] val =
      consume partition_id_to_step_id_trn
    let worker_to_step_id_collector =
      recover trn Map[String, Array[U128] val] end
    for (k, v) in worker_to_step_id_trn.pairs() do
      match worker_to_step_id_trn(k) = recover Array[U128] end
      | let arr: Array[U128] trn =>
        worker_to_step_id_collector(k) = consume arr
      end
    end
    let worker_to_step_id: Map[String, Array[U128] val] val =
      consume worker_to_step_id_collector

    PreStatelessData(pipeline_name, partition_id,
      partition_id_to_worker,
      partition_id_to_step_id, worker_to_step_id,
      threads_per_worker)
