
/*

Copyright 2018 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

use "buffered"
use "collections"
use "files"
use "wallaroo/core/common"
use "wallaroo/core/checkpoint"
use "wallaroo/core/recovery"
use "wallaroo_labs/mort"
use "wallaroo_labs/string_set"


primitive LocalKeysFileCommand
  fun add(): U8 => 0
  fun remove(): U8 => 1

class LocalKeysFile
  // Entry format:
  //   1 - LocalKeysFileCommand
  //   8 - CheckpointId
  //   16 - Step Group RoutingId
  //   4 - Key entry length y
  //   y - Key
  let _file: AsyncJournalledFile iso
  let _filepath: FilePath
  let _writer: Writer

  new create(fpath: FilePath, the_journal: SimpleJournal, auth: AmbientAuth,
    do_local_file_io: Bool)
  =>
    _writer = Writer
    _filepath = fpath
    _file = recover iso AsyncJournalledFile(_filepath, the_journal, auth,
      do_local_file_io) end

  fun ref add_key(step_group: RoutingId, k: Key, checkpoint_id: CheckpointId)
  =>
    let payload_size = 16 + 4 + k.size()

    _writer.u8(LocalKeysFileCommand.add())
    _writer.u64_be(checkpoint_id)

    _writer.u32_be(payload_size.u32())
    _writer.u128_be(step_group)
    _writer.u32_be(k.size().u32())
    _writer.write(k)
    _file.writev(_writer.done())

  fun ref remove_key(step_group: RoutingId, k: Key,
    checkpoint_id: CheckpointId)
  =>
    let payload_size = 16 + 4 + k.size()

    _writer.u8(LocalKeysFileCommand.remove())
    _writer.u64_be(checkpoint_id)

    _writer.u32_be(payload_size.u32())
    _writer.u128_be(step_group)
    _writer.u32_be(k.size().u32())
    _writer.write(k)
    _file.writev(_writer.done())

  fun ref read_local_keys(checkpoint_id: CheckpointId):
    Map[RoutingId, StringSet val] val
  =>
    let lks = Map[RoutingId, StringSet]
    let r = Reader
    _file.seek_start(0)
    if _file.size() > 0 then
      var end_of_checkpoint = false
      while not end_of_checkpoint do
        try
          /////
          // Read next entry
          /////
          //// QQQ r.append(_file.read(1))
          let qqq = _file.read(1)
          r.append(consume qqq)
          let cmd: U8 = r.u8()?
          r.append(_file.read(8))
          let next_cpoint_id = r.u64_be()?
          r.append(_file.read(4))
          let payload_size = r.u32_be()?
          if next_cpoint_id > checkpoint_id then
            // Skip this entry
            _file.seek(payload_size.isize())
          else
            r.append(_file.read(16))
            let step_group = r.u128_be()?
            r.append(_file.read(4))
            let k_size = r.u32_be()?.usize()
            r.append(_file.read(k_size))
            let key: Key = String.from_array(r.block(k_size)?)

            match cmd
            | LocalKeysFileCommand.add() =>
              lks.insert_if_absent(step_group, StringSet)?.set(key)
            | LocalKeysFileCommand.remove() =>
              if lks.contains(step_group) then
                try
                  let keys = lks(step_group)?
                  if keys.contains(key) then
                    keys.unset(key)
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
          end_of_checkpoint = true
        end
      end
    end
    @printf[I32]("Finished reading local keys\n".cstring())

    let lks_iso = recover iso Map[RoutingId, StringSet val] end
    for (r_id, keys) in lks.pairs() do
      let ks = recover iso StringSet end
      for k in keys.values() do
        ks.set(k)
      end
      lks_iso(r_id) = consume ks
    end
    consume lks_iso
