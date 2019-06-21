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

// C FFI prototypes for cut-and-paste into your Pony source, as needed
use @printf[I32](fmt: Pointer[U8] tag, ...)
use @log_enabled[Bool](severity: U8, category: U8)
use @ll_enabled[Bool](sev_cat: U16)
use @l[I32](severity: U8, category: U8, fmt: Pointer[U8] tag, ...)
use @ll[I32](sev_cat: U16, fmt: Pointer[U8] tag, ...)
use @w_set_severity_label[None](severity: U8, label: Pointer[U8] tag)
use @w_set_category_label[None](category: U8, label: Pointer[U8] tag)
use @w_set_severity_threshold[None](severity: U8)
use @w_set_severity_cat_threshold[None](severity: U8, category: U8)
use @w_process_category_overrides[None]()

primitive Log
  // severity levels
  fun none(): U8   => U8(0)
  fun emerg(): U8  => U8(1)
  fun alert(): U8  => U8(2)
  fun crit(): U8   => U8(3)
  fun err(): U8    => U8(4)
  fun warn(): U8   => U8(5)
  fun notice(): U8 => U8(6)
  fun info(): U8   => U8(7)
  fun debug(): U8  => U8(8)
  fun max_severity(): U8 => debug()
  fun default_severity(): U8 => info()

  // categories
  // fun none(): U8             => U8(0) // reuse 0 value from severity none()
  fun checkpoint(): U8       => U8(1)
  fun source_migration(): U8 => U8(2)
  fun twopc(): U8            => U8(3)
  fun dos_client(): U8       => U8(4)
  fun tcp_sink(): U8         => U8(5)
  fun conn_sink(): U8        => U8(6)

  fun severity_map(): Array[(U8, String)] =>
    [ // BEGIN severity_map
      (none(),  "NONE")
      (emerg(),  "EMERGENCY")
      (alert(),  "ALERT")
      (crit(),   "CRITICAL")
      (err(),    "ERROR")
      (warn(),   "WARNING")
      (notice(), "NOTICE")
      (info(),   "INFO")
      (debug(),  "DEBUG")
    ] // END severity_map

  fun category_map(): Array[(U8, U8, String)] =>
    [ // BEGIN category_map
      (default_severity(), none(),             "none")
      (default_severity(), checkpoint(),       "checkpoint")
      (default_severity(), source_migration(), "source-migration")
      (default_severity(), twopc(),            "2PC")
      (default_severity(), dos_client(),       "DOSClient")
      (default_severity(), tcp_sink(),         "TCPSink")
      (default_severity(), conn_sink(),        "ConnectorSink")
    ] // END category_map

  fun set_defaults() =>
    set_severity_labels()
    set_category_labels()
    set_thresholds()

  fun set_severity_labels() =>
    for (severity, label) in severity_map().values() do
      @w_set_severity_label(severity, label.cstring())
    end

  fun set_category_labels() =>
    for (severity, category, label) in category_map().values() do
      @w_set_category_label(category, label.cstring())
    end

  fun set_thresholds(do_defaults: Bool = true, do_overrides: Bool = true) =>
    if do_defaults then
      @w_set_severity_threshold(default_severity())
      for (severity, category, label) in category_map().values() do
        @w_set_severity_cat_threshold(severity, category)
      end
    end

    if do_overrides then
      @w_process_category_overrides[None]()
    end

  fun make_sev_cat(severity: U8, category: U8): U16 =>
    severity.u16().shl(8) + category.u16()
