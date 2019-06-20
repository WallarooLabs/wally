/*

Copyright 2019 The Wallaroo Authors.

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

// Tell ponyc that we're going to use the external C functions
// in the libwallaroo-logging.a library.
use "lib:wallaroo-logging"

primitive Log
  // severity levels
  fun emerg(): U8  => U8(0)
  fun alert(): U8  => U8(1)
  fun crit(): U8   => U8(2)
  fun err(): U8    => U8(3)
  fun warn(): U8   => U8(4)
  fun notice(): U8 => U8(5)
  fun info(): U8   => U8(6)
  fun debug(): U8  => U8(7)
  fun max_severity() => debug()

  // categories
  fun c_checkpoint(): U8       => U8(0)
  fun c_source_migration(): U8 => U8(1)
  fun c_2pc(): U8              => U8(2)
  fun c_dos_client(): U8       => U8(3)

  fun category_map(): Array[(U8, String)] =>
    [
      (c_checkpoint(),       "CHECKPOINT")
      (c_source_migration(), "SOURCE_MIGRATION")
      (c_2pc(),              "2PC")
      (c_dos_client(),       "DOS_CLIENT")
    ]

  fun set_categories() =>
    for (cat, label) in category_map().values() do
      @w_set_category[None](cat, label.cstring())
    end