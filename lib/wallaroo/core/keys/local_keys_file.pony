
use "buffered"
use "collections"
use "files"
use "wallaroo/core/common"
use "wallaroo/ent/snapshot"
use "wallaroo_labs/mort"


primitive LocalKeysFileCommand
  fun add(): U8 => 0
  fun remove(): U8 => 1

class LocalKeysFile
  // Entry format:
  //   1 - LocalKeysFileCommand
  //   8 - SnapshotId
  //   4 - StateName entry length x
  //   x - StateName
  //   4 - Key entry length y
  //   y - Key
  //   16 - RoutingId <--- only for add()
  let _file: File iso
  let _filepath: FilePath
  let _writer: Writer

  new create(fpath: FilePath) =>
    _writer = Writer
    _filepath = fpath
    _file = recover iso File(_filepath) end

  fun ref add_key(state_name: StateName, k: Key, r_id: RoutingId,
    snapshot_id: SnapshotId)
  =>
    let payload_size = 4 + state_name.size() + 4 + k.size() + 16

    _writer.u8(LocalKeysFileCommand.add())
    _writer.u64_be(snapshot_id)

    _writer.u32_be(payload_size.u32())
    _writer.u32_be(state_name.size().u32())
    _writer.write(state_name)
    _writer.u32_be(k.size().u32())
    _writer.write(k)
    _writer.u128_be(r_id)
    _file.writev(_writer.done())

  fun ref remove_key(state_name: StateName, k: Key, snapshot_id: SnapshotId) =>
    let payload_size = 4 + state_name.size() + 4 + k.size()

    _writer.u8(LocalKeysFileCommand.remove())
    _writer.u64_be(snapshot_id)

    _writer.u32_be(payload_size.u32())
    _writer.u32_be(state_name.size().u32())
    _writer.write(state_name)
    _writer.u32_be(k.size().u32())
    _writer.write(k)
    _file.writev(_writer.done())

  fun ref read_local_keys_and_truncate(snapshot_id: SnapshotId):
    Map[StateName, Map[Key, RoutingId] val] val
  =>
    let lks = Map[StateName, Map[Key, RoutingId]]
    let r = Reader
    _file.seek_start(0)
    if _file.size() > 0 then
      var end_of_snapshot = false
      while not end_of_snapshot do
        try
          /////
          // Read next entry
          /////
          r.append(_file.read(1))
          @printf[I32]("!@cmd\n".cstring())
          let cmd: U8 = r.u8()?
          @printf[I32]("!@next_snap_id\n".cstring())
          r.append(_file.read(8))
          let next_snap_id = r.u64_be()?
          @printf[I32]("!@payload_size\n".cstring())
          r.append(_file.read(4))
          let payload_size = r.u32_be()?
          if next_snap_id > snapshot_id then
            // Skip this entry
            _file.seek(payload_size.isize())
          else
            r.append(_file.read(4))
            @printf[I32]("!@s_name_size\n".cstring())
            let s_name_size = r.u32_be()?.usize()
            r.append(_file.read(s_name_size))
            @printf[I32]("!@s_name\n".cstring())
            let s_name: StateName = String.from_array(r.block(s_name_size)?)
            r.append(_file.read(4))
            @printf[I32]("!@k_size\n".cstring())
            let k_size = r.u32_be()?.usize()
            r.append(_file.read(k_size))
            @printf[I32]("!@key\n".cstring())
            let key: Key = String.from_array(r.block(k_size)?)

            match cmd
            | LocalKeysFileCommand.add() =>
              r.append(_file.read(16))
              @printf[I32]("!@routing_id\n".cstring())
              let routing_id = r.u128_be()?
              lks.insert_if_absent(s_name, Map[Key, RoutingId])?(key) =
                routing_id
            | LocalKeysFileCommand.remove() =>
              if lks.contains(s_name) then
                try
                  @printf[I32]("!@lks(s_name)?\n".cstring())
                  let keys = lks(s_name)?
                  if keys.contains(key) then
                    keys.remove(key)?
                  end
                else
                  Fail()
                end
              end
            else
              Fail()
            end
          end
        else
          @printf[I32]("Error reading local keys file!\n".cstring())
          Fail()
        end
        if _file.size() == _file.position() then
          end_of_snapshot = true
        end
      end
    end

    // Truncate rest of file since we are rolling back to an earlier
    // snapshot.
    _file.set_length(_file.position())

    let lks_iso = recover iso Map[StateName, Map[Key, RoutingId] val] end
    for (s, keys) in lks.pairs() do
      let ks = recover iso Map[Key, RoutingId] end
      for (k, r_id) in keys.pairs() do
        ks(k) = r_id
      end
      lks_iso(s) = consume ks
    end
    consume lks_iso
