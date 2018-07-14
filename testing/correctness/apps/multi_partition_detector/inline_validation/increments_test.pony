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

primitive IncrementsTest
  fun apply(values: Array[U64] val): Bool =>
  """
  Test that values increment by 1, except for leading zeroes.
  """
    // if values size is less than 2 then it isn't testable.
    if values.size() < 1 then
      return false
    elseif values.size() == 1 then
      try
        if values(0)? == 1 then
          return true
        else
          return false
        end
      else
        return false
      end
    end
    // diff may be 0 or 1 and only 1 after 1
    try
      var previous: U64 = values(0)?
      for pos in Range[USize](1, values.size()) do
        let cur = values(pos)?
        let diff = cur - previous
        if (diff == 0) then
          if previous != 0 then
            return false
          else
            previous = cur
          end
        elseif diff != 1 then
          return false
        else
          previous = cur
        end
      end
    else
      return false
    end
    true
