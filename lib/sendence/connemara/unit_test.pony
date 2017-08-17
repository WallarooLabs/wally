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

trait UnitTest
  """
  Each unit test class must provide this trait. Simple tests only need to
  define the name() and apply() functions. The remaining functions specify
  additional test options.
  """

  fun name(): String
    """
    Report the test name, which is used when printing test results and on the
    command line to select tests to run.
    """

  fun exclusion_group(): String =>
    """
    Report the test exclusion group, returning an empty string for none.
    The default body returns an empty string.
    """
    ""

  fun ref apply(h: TestHelper) ?
    """
    Run the test.
    Raising an error is interpreted as a test failure.
    """

  fun ref timed_out(h: TestHelper) =>
    """
    Tear down a possibly hanging test.
    Called when the timeout specified by to long_test() expires.
    There is no need for this function to call complete(false).
    tear_down() will still be called after this completes.
    The default is to do nothing.
    """
    None

  fun ref tear_down(h: TestHelper) =>
    """
    Tidy up after the test has completed.
    Called for each run test, whether that test passed, succeeded or timed out.
    The default is to do nothing.
    """
    None

  fun label(): String =>
    """
    Report the test label, returning an empty string for none.
    It can be later use to filter tests which we want to run, by labels.
    """
    ""
