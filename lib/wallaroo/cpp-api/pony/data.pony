type DataP is ManagedObjectP

class CPPData
  let _data: CPPManagedObject

  new create(data: CPPManagedObject) =>
    _data = data

  fun obj(): DataP =>
    _data.obj()
