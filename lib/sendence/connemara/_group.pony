/*

Copyright (C) 2016-2017, Sendence LLC
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

trait tag _Group
  """
  Test exclusion is achieved by organising tests into groups. Each group can be
  exclusive, ie only one test is run at a time, or simultaneous, ie all tests
  are run concurrently.
  """

  be apply(runner: _TestRunner)
    """
    Run the given test, or queue it and run later, as appropriate.
    """

  be _test_complete(runner: _TestRunner)
    """
    The specified test has completed.
    """

actor _ExclusiveGroup is _Group
  """
  Test group in which we only ever have one test running at a time.
  """

  embed _tests: Array[_TestRunner] = Array[_TestRunner]
  var _next: USize = 0
  var _in_test:Bool = false

  be apply(runner: _TestRunner) =>
    if _in_test then
      // We're already running one test, save this one for later
      _tests.push(runner)
    else
      // Run test now
      _in_test = true
      runner.run()
    end

  be _test_complete(runner: _TestRunner) =>
    _in_test = false

    if _next < _tests.size() then
      // We have queued tests, run the next one
      try
        let next_test = _tests(_next)
        _next = _next + 1
        _in_test = true
        next_test.run()
      end
    end


actor _SimultaneousGroup is _Group
  """
  Test group in which all tests can run concurrently.
  """

  be apply(runner: _TestRunner) =>
    // Just run the test
    runner.run()

  be _test_complete(runner: _TestRunner) =>
    // We don't care about tests finishing
    None
