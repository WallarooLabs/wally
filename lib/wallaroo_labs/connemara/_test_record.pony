/*

Copyright (C) 2016-2017, Wallaroo Labs
Copyright (C) 2016-2017, The Pony Developers
Copyright (c) 2014-2015, Causality Ltd.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

class _TestRecord
  """
  Store and report the result and log from a single test.
  """

  let _env: Env
  let name: String
  var _pass: Bool = false
  var _log: (Array[String] val | None) = None

  new create(env: Env, name': String) =>
    _env = env
    name = name'

  fun ref _result(pass: Bool, log: Array[String] val) =>
    """
    Our test has completed, store the result.
    """
    _pass = pass
    _log = log

  fun _report(log_all: Bool): Bool =>
    """
    Print our test summary, including the log if appropriate.
    The log_all parameter indicates whether we've been told to print logs for
    all tests. The default is to only print logs for tests that fail.
    Returns our pass / fail status.
    """
    var show_log = log_all

    if _pass then
      _env.out.print(_Color.green() + "---- Passed: " + name + _Color.reset())
    else
      _env.out.print(_Color.red() + "**** FAILED: " + name + _Color.reset())
      show_log = true
    end

    if show_log then
      match _log
      | let log: Array[String] val =>
        // Print the log. Simply print each string in the array.
        for msg in log.values() do
          _env.out.print(msg)
        end
      end
    end

    _pass

  fun _list_failed() =>
    """
    Print our test name out in the list of failed test, if we failed.
    """
    if not _pass then
      _env.out.print(_Color.red() + "**** FAILED: " + name + _Color.reset())
    end
