use @w_data_serialize_get_size[USize](data: DataP)
use @w_data_serialize[None](data: DataP, bytes: Pointer[U8] tag, size: USize)
use @w_data_deserialize[DataP](bytes: Pointer[U8] tag, size: USize)

type DataP is ManagedObjectP

primitive CPPDataDeserialize
  fun apply(bytes: Array[U8] val): CPPData =>
    CPPData(CPPManagedObject(@w_data_deserialize(bytes.cpointer(), bytes.size())))

class CPPData
  let _data: CPPManagedObject

  new create(data: CPPManagedObject) =>
    _data = data

  fun serialize(): Array[U8] val =>
    let size = @w_data_serialize_get_size(obj())
    let bytes = recover val
      let b = Array[U8].undefined(size)
      @w_data_serialize(obj(), b.cpointer(), size)
      b
    end
    bytes

  fun obj(): DataP =>
    _data.obj()
