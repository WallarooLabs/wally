use "collections"
use "wallaroo/core/common"


//!@
// primitive StatelessPartitions
//   fun pre_stateless_data(pipeline_name: String, partition_id: RoutingId,
//     workers: Array[String] val, threads_per_worker: USize): PreStatelessData ?
//   =>
//     let routing_id_gen = RoutingIdGenerator

//     // First we calculate the size of the partition and determine
//     // where the steps in the partition go in the cluster. We are
//     // populating three maps. Two of them, partition_idx_to_worker
//     // and partition_idx_to_step_id, will be used to create a
//     // StatelessPartitionRouter during local topology
//     // initialization. The third, worker_to_step_id, will be used
//     // here to determine which step ids we will put in which
//     // local graphs.
//     let ws = Array[String]
//     for w in workers.values() do ws.push(w) end
//     let sorted_workers = Sort[Array[String], String](ws)
//     let worker_count = workers.size()
//     let partition_count = worker_count * threads_per_worker
//     let partition_idx_to_worker_trn =
//       recover trn Map[SeqPartitionIndex, String] end
//     let partition_idx_to_step_id_trn =
//       recover trn Map[SeqPartitionIndex, RoutingId] end
//     let worker_to_step_id_trn =
//       recover trn Map[String, Array[RoutingId] trn] end
//     for w in sorted_workers.values() do
//       worker_to_step_id_trn(w) = recover Array[RoutingId] end
//     end
//     for id in Range[SeqPartitionIndex](0, partition_count.u64()) do
//       let step_id = routing_id_gen()
//       partition_idx_to_step_id_trn(id) = step_id
//       let w = sorted_workers(id.usize() % worker_count)?
//       partition_idx_to_worker_trn(id) = w
//       worker_to_step_id_trn(w)?.push(step_id)
//     end
//     let partition_idx_to_worker: Map[SeqPartitionIndex, String] val =
//       consume partition_idx_to_worker_trn
//     let partition_idx_to_step_id: Map[SeqPartitionIndex, RoutingId] val =
//       consume partition_idx_to_step_id_trn
//     let worker_to_step_id_collector =
//       recover trn Map[String, Array[RoutingId] val] end
//     for (k, v) in worker_to_step_id_trn.pairs() do
//       match worker_to_step_id_trn(k) = recover Array[RoutingId] end
//       | let arr: Array[RoutingId] trn =>
//         worker_to_step_id_collector(k) = consume arr
//       end
//     end
//     let worker_to_step_id: Map[String, Array[RoutingId] val] val =
//       consume worker_to_step_id_collector

//     PreStatelessData(pipeline_name, partition_id,
//       partition_idx_to_worker,
//       partition_idx_to_step_id, worker_to_step_id,
//       threads_per_worker)
