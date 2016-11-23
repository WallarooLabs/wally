use "collections"

use @w_key_hash[U64](key: KeyP)
use @w_key_eq[Bool](key: KeyP, other: KeyP)

type KeyP is ManagedObjectP

class CPPKey is (Hashable & Equatable[CPPKey])
  let _key: CPPManagedObject

  new create(key: CPPManagedObject) =>
    _key = key

  fun obj(): KeyP =>
    _key.obj()

  fun hash(): U64 =>
    @w_key_hash(obj())

  fun eq(other: CPPKey box): Bool =>
    @w_key_eq(obj(), other.obj())