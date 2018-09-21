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

primitive _D
  fun d(fmt: String) =>
    ifdef "dos-verbose" then
      @printf[I32](fmt.cstring())
    end

  fun d6(fmt: String, a1: USize) =>
    ifdef "dos-verbose" then
      @printf[I32](fmt.cstring(), a1)
    end

  fun d8(fmt: String, a1: U8) =>
    ifdef "dos-verbose" then
      @printf[I32](fmt.cstring(), a1)
    end

  fun ds(fmt: String, a1s: String) =>
    ifdef "dos-verbose" then
      @printf[I32](fmt.cstring(), a1s.cstring())
    end

  fun d66(fmt: String, a1: USize, a2: USize) =>
    ifdef "dos-verbose" then
      @printf[I32](fmt.cstring(), a1, a2)
    end

  fun d86(fmt: String, a1: U8, a2: USize) =>
    ifdef "dos-verbose" then
      @printf[I32](fmt.cstring(), a1, a2)
    end

  fun d8s(fmt: String, a1: U8, a2: String) =>
    ifdef "dos-verbose" then
      @printf[I32](fmt.cstring(), a1, a2.cstring())
    end

  fun ds6(fmt: String, a1s: String, a1a: USize) =>
    ifdef "dos-verbose" then
      @printf[I32](fmt.cstring(), a1s.cstring(), a1a)
    end

  fun dss(fmt: String, a1: String, a2: String) =>
    ifdef "dos-verbose" then
      @printf[I32](fmt.cstring(), a1.cstring(), a2.cstring())
    end

  fun d666(fmt: String, a1: USize, a2: USize, a3: USize) =>
    ifdef "dos-verbose" then
      @printf[I32](fmt.cstring(), a1, a2, a3)
    end

  fun d866(fmt: String, a1: U8, a2: USize, a3: USize) =>
    ifdef "dos-verbose" then
      @printf[I32](fmt.cstring(), a1, a2, a3)
    end

  fun d8s6(fmt: String, a1: U8, a2: String, a3: USize) =>
    ifdef "dos-verbose" then
      @printf[I32](fmt.cstring(), a1, a2.cstring(), a3)
    end

  fun ds66(fmt: String, a1: String, a2: USize, a3: USize) =>
    ifdef "dos-verbose" then
      @printf[I32](fmt.cstring(), a1.cstring(), a2, a3)
    end

  fun ds6s(fmt: String, a1: String, a2: USize, a3: String) =>
    ifdef "dos-verbose" then
      @printf[I32](fmt.cstring(), a1.cstring(), a2, a3.cstring())
    end

  fun dss6(fmt: String, a1: String, a2: String, a3: USize) =>
    ifdef "dos-verbose" then
      @printf[I32](fmt.cstring(), a1.cstring(), a2.cstring(), a3)
    end

  fun dss66(fmt: String, a1: String, a2: String, a3: USize, a4: USize) =>
    ifdef "dos-verbose" then
      @printf[I32](fmt.cstring(), a1.cstring(), a2.cstring(), a3, a4)
    end

  fun ds666(fmt: String, a1: String, a2: USize, a3: USize, a4: USize) =>
    ifdef "dos-verbose" then
      @printf[I32](fmt.cstring(), a1.cstring(), a2, a3, a4)
    end

  fun ds666s(fmt: String, a1: String, a2: USize, a3: USize, a4: USize, a5: String) =>
    ifdef "dos-verbose" then
      @printf[I32](fmt.cstring(), a1.cstring(), a2, a3, a4, a5.cstring())
    end

  fun ds6666(fmt: String, a1: String, a2: USize, a3: USize, a4: USize, a5: USize) =>
    ifdef "dos-verbose" then
      @printf[I32](fmt.cstring(), a1.cstring(), a2, a3, a4, a5)
    end

  fun ds66666(fmt: String, a1: String, a2: USize, a3: USize, a4: USize, a5: USize, a6: USize) =>
    ifdef "dos-verbose" then
      @printf[I32](fmt.cstring(), a1.cstring(), a2, a3, a4, a5, a6)
    end
