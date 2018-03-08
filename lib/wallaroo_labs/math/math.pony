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

primitive Math
  fun lcm(x: USize, y: USize): USize =>
    """
    Get least common multiple of x and y

    Returns 0 rather than an error if either is 0.
    Watch your inputs.
    """

    (x*y)/gcd(x, y)

  fun gcd(x: USize, y: USize): USize =>
    """
    Get greatest common denominator of x and y

    Returns 0 if either is 0.
    Watch your inputs.
    """

    if (x == 0) or (y == 0) then
      return 0
    end

    var x': USize = x
    var y': USize = y

    while y' != 0 do
      let t = y'
      y' = x' % y'
      x' = t
    end

    x'
