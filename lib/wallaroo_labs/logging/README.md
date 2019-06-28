
# Using the Log logging library

## Prerequisites

```
// For each source file that uses the `Log` primitive
use "wallaroo_labs/logging"

// If no Pony source files contain a
//     use "wallaroo_labs/logging"
// statement, then add the following to access the C FFI
// functions in the "libwallaroo-logging.a" library.
use "lib:wallaroo-logging"

```

## Setup

Early in your Wallaroo app, call `Log.set_defaults()` prior to calling any
of the public API function described below.

## Using the logging C FFI functions

The top of `wallaroo-logging.pony` has several FFI type specs to
cut-and-paste into your Pony source, as needed

```
use @l_enabled[Bool](severity: LogSeverity, category: LogCategory)
use @ll_enabled[Bool](sev_cat: U16)
use @l[I32](severity: LogSeverity, category: LogCategory, fmt: Pointer[U8] tag, ...)
use @ll[I32](sev_cat: U16, fmt: Pointer[U8] tag, ...)
```

The log messages created by the `@l()` and `@ll()` functions are formatted
using `sprintf(3)`-style formatting conventions.  The one difference
is that this library will add a trailing newline/'\n' character to the
format string.

Log a message at `info` severity for the `checkpoint` category in the
two argument style:

```
@l(Log.info(), Log.checkpoint(), "Hello, lucky %d".cstring(), 7)
```

Log a message at `info` severity for the `checkpoint` category in the
one argument style

```
// without var
@ll(Log.make_sev_crit(Log.info(), Log.checkpoint()), "Hello, lucky %d".cstring(), 7)

// with var
let info = Log.make_sev_crit(Log.info(), Log.checkpoint())
@ll(info, "Hello, lucky %d".cstring(), 7)
```

If message formatting is expensive, then Pony code may wish to check
if a severity + category is enabled prior to formatting.  Use
`@l_enabled()` or `@ll_enabled()`:

```
if (@l_enabled(Log.info(), Log.checkpoint())) then ... end

let info = Log.make_sev_crit(Log.info(), Log.checkpoint())
if (@ll_enabled(info)) then ... end
```

## Setting label and severity thresholds

To set new labels for severity & categories:

```
@w_set_severity_label(LogSeverity(8), "Special Debug label".cstring())
@w_set_category_label(LogCategory(33), "easter egg".cstring())
```

To set a severity threshold for all categories or for a specific
category, respectively:

```
@w_set_severity_threshold(LogSeverity(8))
@w_set_severity_cat_threshold(LogSeverity(8), LogCategory(33))
```

To parse the `WALLAROO_THRESHOLDS` environment variable for overriding
the thresholds set by `Log.set_defaults()`:

```
@w_process_category_overrides()
```