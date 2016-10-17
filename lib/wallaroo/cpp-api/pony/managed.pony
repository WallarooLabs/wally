use @w_managed_object_delete[None](obj: ManagedObjectP)

type ManagedObjectP is Pointer[U8] val

class CPPManagedObject
  let _obj: ManagedObjectP

  new create(obj': ManagedObjectP) =>
    _obj = obj'

  fun obj(): ManagedObjectP =>
    _obj

  fun _final() =>
    @w_managed_object_delete(_obj)
