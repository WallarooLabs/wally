type DataP is ManagedObjectP

class CPPData
  let _data: CPPManagedObject

  new create(data: CPPManagedObject) =>
    _data = data

  fun obj(): DataP =>
    _data.obj()
  
  fun hash(): U64 =>
    _data.hash()

  fun eq(other: CPPData): Bool =>
    _data.hash() == other.hash()

  fun partition_index(): U64 =>
    _data.partition_index()
