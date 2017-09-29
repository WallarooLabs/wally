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

use "collections"

primitive TestIncrements
  fun apply(values: Array[U64] val): Bool =>
  """
  Test that values are incrementing correctly, except for leading zeroes.
  """
    // diff may be 0, 1, or 2, and only 2 after 1 or 2
    try
      var previous: U64 = values(0)?
      for pos in Range[USize](1,4) do
        let cur = values(pos)?
        let diff = cur - previous
        if (diff == 0) or (diff == 1) then
          if previous != 0 then
            return false
          else
            previous = cur
          end
        elseif diff != 2 then
          return false
        else
          previous = cur
        end
      end
    else
      return false
    end
    true
