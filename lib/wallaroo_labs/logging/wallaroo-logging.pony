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

// LogSeverity is a U16 which is the same size as the
// combined severity + category, which is weird but
// intentional.  For more details, see comments in
// make_sev_cat() or the PR that added this file.
type LogSeverity is U16
type LogCategory is U16

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
  fun no_cat(): LogCategory           => LogCategory(0).shl(8)
  fun checkpoint(): LogCategory       => LogCategory(1).shl(8)
  fun source_migration(): LogCategory => LogCategory(2).shl(8)
  fun twopc(): LogCategory            => LogCategory(3).shl(8)
  fun dos_client(): LogCategory       => LogCategory(4).shl(8)
  fun tcp_sink(): LogCategory         => LogCategory(5).shl(8)
  fun conn_sink(): LogCategory        => LogCategory(6).shl(8)
  fun tcp_source(): LogCategory       => LogCategory(7).shl(8)
  fun conn_source(): LogCategory      => LogCategory(8).shl(8)
  fun max_category(): LogCategory     => LogCategory(40).shl(8)
  fun manual_category(n: U16): LogCategory  => LogCategory(n).shl(8)

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
    """
    Set default severity labels, category labels, and default
    severity threshold for use in all Wallaroo apps.  This function
    should be called very early in a Wallaroo application's code,
    before the first call to @l() or @ll().

    """
    set_severity_labels()
    set_category_labels()
    set_thresholds()

  fun set_severity_labels() =>
    """
    Set syslog-style printable labels for all severity values.
    """
    for (severity, label) in severity_map().values() do
      @w_set_severity_label(severity, label.cstring())
    end

  fun set_category_labels() =>
    """
    Set Wallaroo app subsystem labels for commonly-used categories.
    """
    for (severity, category, label) in category_map().values() do
      @w_set_category_label(category, label.cstring())
    end

  fun set_thresholds(do_defaults: Bool = true, do_overrides: Bool = true) =>
    """
    Set the default and/or override logging severity thresholds for
    Wallaroo app logging categories.  Default thresholds are specified
    by the category_map() function.  Override thresholds are specified
    by the environment variable WALLAROO_THRESHOLDS and parsed & set
    by C FFI function @w_process_category_overrides().

    WALLAROO_THRESHOLDS formatting:

    ** The string should contain a list of zero or more
    ** category.severity pairs, e.g, "22.6" for category 22 and
    ** severity 6 (which corresponds to Log.notice()).  The string
    ** "*" can be used to specify all categories.
    **
    ** Items in the list are separated by commas and are processed
    ** in order.  The "*" for all categories, if used, probably ought
    ** to be first in the list.  For example, "*.1,22.6,3.7,4.0".
    """
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
    """
    Merge together a severity and category into a single U16 for
    use with the @ll() function.  (NOTE: The @l() function uses two
    separate arguments to specify severity and category.)

    Assume that users may not want to specify a category, so we put
    the more important severity in bits 0-7 and put the category in
    bits 8-15.
    """
    category + severity
