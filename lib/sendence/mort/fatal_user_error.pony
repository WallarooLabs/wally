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

primitive FatalUserError
  """
  An error was encountered due to bad input from the user in terms of startup
  options or configuration. Exit and inform them of the problem.
  """
  fun apply(msg: String) =>
    @fprintf[I32](
      @pony_os_stderr[Pointer[U8]](), "Error: %s\n".cstring(), msg.cstring())
    @exit[None](U8(1))
