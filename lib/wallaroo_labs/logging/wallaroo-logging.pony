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
use @l_enabled[Bool](severity: LogSeverity, category: LogCategory)
use @ll_enabled[Bool](sev_cat: U16)
use @l[I32](severity: LogSeverity, category: LogCategory, fmt: Pointer[U8] tag, ...)
use @ll[I32](sev_cat: U16, fmt: Pointer[U8] tag, ...)
use @w_set_severity_label[None](severity: LogSeverity, label: Pointer[U8] tag)
use @w_set_category_label[None](category: LogCategory, label: Pointer[U8] tag)
use @w_set_severity_threshold[None](severity: LogSeverity)
use @w_set_severity_cat_threshold[None](severity: LogSeverity, category: LogCategory)
use @w_process_category_overrides[None]()

type LogCategory is U8
type LogSeverity is U8

primitive Log
  // severity levels
  fun no_sev(): LogSeverity   => LogSeverity(0)
  fun emerg(): LogSeverity  => LogSeverity(1)
  fun alert(): LogSeverity  => LogSeverity(2)
  fun crit(): LogSeverity   => LogSeverity(3)
  fun err(): LogSeverity    => LogSeverity(4)
  fun warn(): LogSeverity   => LogSeverity(5)
  fun notice(): LogSeverity => LogSeverity(6)
  fun info(): LogSeverity   => LogSeverity(7)
  fun debug(): LogSeverity  => LogSeverity(8)
  fun max_severity(): LogSeverity => debug()
  fun default_severity(): LogSeverity => info()

  // categories
  fun no_cat(): LogCategory           => LogCategory(0)
  fun checkpoint(): LogCategory       => LogCategory(1)
  fun source_migration(): LogCategory => LogCategory(2)
  fun twopc(): LogCategory            => LogCategory(3)
  fun dos_client(): LogCategory       => LogCategory(4)
  fun tcp_sink(): LogCategory         => LogCategory(5)
  fun conn_sink(): LogCategory        => LogCategory(6)
  fun tcp_source(): LogCategory       => LogCategory(7)
  fun conn_source(): LogCategory      => LogCategory(8)
  fun max_category(): LogCategory     => LogCategory(40)

  fun severity_map(): Array[(LogSeverity, String)] =>
    [ // BEGIN severity_map
      (no_sev(), "NONE")
      (emerg(),  "EMERGENCY")
      (alert(),  "ALERT")
      (crit(),   "CRITICAL")
      (err(),    "ERROR")
      (warn(),   "WARNING")
      (notice(), "NOTICE")
      (info(),   "INFO")
      (debug(),  "DEBUG")
    ] // END severity_map

  fun category_map(): Array[(LogSeverity, LogCategory, String)] =>
    [ // BEGIN category_map
      (default_severity(), no_cat(),           "none")
      (default_severity(), checkpoint(),       "checkpoint")
      (default_severity(), source_migration(), "source-migration")
      (default_severity(), twopc(),            "2PC")
      (default_severity(), dos_client(),       "DOSClient")
      (default_severity(), tcp_sink(),         "TCPSink")
      (default_severity(), conn_sink(),        "ConnectorSink")
      (default_severity(), tcp_source(),       "TCPSource")
      (default_severity(), conn_source(),      "ConnectorSource")
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

  fun make_sev_cat(severity: LogSeverity, category: LogCategory): U16 =>
    // Assume that users may not want to specify a category, so we put
    // the more important severity in bits 0-7 and put the category in
    // bits 8-15.
    category.u16().shl(8) + severity.u16()
