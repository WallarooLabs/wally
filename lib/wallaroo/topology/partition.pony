use "collections"

interface PartitionFunction[In: Any val, Key: (Hashable val & Equatable[Key] val)]
  fun apply(input: In): Key

interface PartitionFindable
  fun find_partition(finder: PartitionFinder val): Router val

interface PartitionFinder
  fun find[D: Any val](data: D): Router val

class StatelessPartitionFinder[In: Any val, Key: (Hashable val & Equatable[Key] val)] 
  let _partition_function: PartitionFunction[In, Key] val
  let _partitions: Map[Key, Router val] = Map[Key, Router val]

  new val create(pf: PartitionFunction[In, Key] val, keys: Array[Key] val,
    router_builder: RouterBuilder val) =>
    _partition_function = pf
    for key in keys.values() do
      _partitions(key) = router_builder()
    end

  fun find[D: Any val](data: D): Router val =>
    try
      match data
      | let input: In =>
        _partitions(_partition_function(input))
      else
        EmptyRouter
      end
    else
      EmptyRouter
    end

class StatePartitionFinder[In: Any val, Key: (Hashable val & Equatable[Key] val)] 
  let _partition_function: PartitionFunction[In, Key] val
  let _partitions: Map[Key, Router val] = Map[Key, Router val]

  new val create(pf: PartitionFunction[In, Key] val, keys: Array[Key] val,
    router_builder: RouterBuilder val) =>
    _partition_function = pf
    for key in keys.values() do
      _partitions(key) = router_builder()
    end

  fun find[D: Any val](data: D): Router val =>
    try
      match data
      | let input: In =>
        _partitions(_partition_function(input))
      else
        EmptyRouter
      end
    else
      EmptyRouter
    end
