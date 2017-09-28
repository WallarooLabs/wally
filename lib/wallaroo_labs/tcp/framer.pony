/*

Copyright 2017 The Wallaroo Authors.

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

"""
# TCP package
"""
use "wallaroo_labs/bytes"

class Framer
  """
  Process data coming in from TCP and use the first 4 bytes as framing info.
  Allows you to accumulate data in a running fashion getting 1 or more messages
  as you go along.
  """
  var _buffer: Array[U8] = Array[U8]
  var _data_index: USize = 0
  // How many bytes are left to process for current message
  var _left: U32 = 0
  // For building up the two bytes of a U16 message length
  var _len_bytes: Array[U8] = Array[U8]

  fun ref chunk(data: Array[U8] iso): Array[Array[U8] val] =>
    let d: Array[U8] ref = consume data
    let out: Array[Array[U8] val] = Array[Array[U8] val]

    try
      _data_index = 0
      while d.size() > 0 do
        if _left == 0 then
          if _len_bytes.size() < 4 then
            let next = d(_data_index = _data_index + 1)?
            _len_bytes.push(next)
          else
            // Set _left to the length of the current message in bytes
            _left = Bytes.to_u32(_len_bytes(0)?, _len_bytes(1)?, _len_bytes(2)?,
              _len_bytes(3)?)
            _len_bytes = Array[U8]
          end
        else
          _buffer.push(d(_data_index = _data_index + 1)?)
          _left = _left - 1
          if _left == 0 then
            let copy: Array[U8] iso = recover Array[U8] end
            for byte in _buffer.values() do
              copy.push(byte)
            end
            out.push(consume copy)
            _buffer = Array[U8]
          end
        end
      end
    end

    out
