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

primitive Fail
  """
  'This should never happen' error encountered. Bail out of our running
  program. Print where the error happened and exit.
  """
  fun apply(loc: SourceLoc = __loc) =>
    @fprintf[I32](
      @pony_os_stderr[Pointer[U8]](),
      "This should never happen: failure in %s at line %s\n".cstring(),
      loc.file().cstring(),
      loc.line().string().cstring())
    @exit[None](U8(1))
