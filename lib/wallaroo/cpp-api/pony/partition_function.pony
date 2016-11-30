use @w_partition_function_partition[KeyP](partition_function: PartitionFunctionP, data: DataP)
use @w_partition_function_u64_partition[U64](partition_function: PartitionFunctionP, data: DataP)

type PartitionFunctionP is ManagedObjectP

class CPPPartitionFunction
  let _partition_function: CPPManagedObject val
  
  new create(partition_function: CPPManagedObject val) =>
    _partition_function = partition_function

  fun obj(): PartitionFunctionP =>
    _partition_function.obj()

  fun apply(data: CPPData val): CPPKey val =>
    recover CPPKey(CPPManagedObject(@w_partition_function_partition(obj(), data.obj()))) end

class CPPPartitionFunctionU64
  let _partition_function: CPPManagedObject val
  
  new create(partition_function: CPPManagedObject val) =>
    _partition_function = partition_function

  fun obj(): PartitionFunctionP =>
    _partition_function.obj()

  fun apply(data: CPPData val): U64 =>
    @w_partition_function_u64_partition(obj(), data.obj())
