//!@
// primitive _LFQ
// primitive _Data

// use @lfq_init[None](q: Pointer[_LFQ], queue_size: U32,
//   data: Pointer[Pointer[_Data]])
// use @lfq_enqueue[I32](item: ByteSeq)
// use @lfq_dequeue[ByteSeq]()
// use @lfq_empty[I32]()


// class TestLockFreeQueue
//   let _lfq: Pointer[_LFQ] = Pointer[_LFQ]

//   new create() =>
//     @lfq_init(_lfq, 10_000, Pointer[Pointer[_Data]])

//   fun is_empty(): Bool =>
//     not (@lfq_empty(_lfq) == 0)

//   fun ref enqueue(b: ByteSeq) =>
//     @lfq_enqueue(b)

//   fun ref dequeue(): ByteSeq =>
//     @lfq_dequeue()
