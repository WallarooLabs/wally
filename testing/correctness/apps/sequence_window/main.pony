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

"""
Sequence Window is an application designed to test recovery

It holds the last 4 values observed in an ordered ring buffer, and on every
incoming new value, it replaces the oldest value with the new value, and prints
the last 4 values (including the current one).

The ring buffer holding the last 4 values represents Stateful memory that should
be recovered. The input is a binary encoded sequence of U64 integers,
and the output is the encoded string of the array, in the format
"[a, b, c, d]\n"

To run, use the following commands:
1. Data receiver:
```bash
../../../../utils/data_receiver/data_receiver --framed --ponythreads=1 --ponynoblock \
--ponypinasio -l 127.0.0.1:5555
```
2. Initializer worker
```bash
./sequence_window -i "Sequence Window"@127.0.0.1:7000 \
-o 127.0.0.1:5555 -m 127.0.0.1:5001 \
--ponythreads=4 --ponypinasio --ponynoblock -c 127.0.0.1:12500 \
-d 127.0.0.1:12501 -r res-data -w 2 -n worker1 -t
```
3. Second worker
```bash
./sequence_window -i "Sequence Window"@127.0.0.1:7001 \
-o 127.0.0.1:5555 -m 127.0.0.1:5001 \
--ponythreads=4 --ponypinasio --ponynoblock -c 127.0.0.1:12500 \
-r res-data -n worker2
```
4. Sender
```bash
../../../../giles/sender/sender -h 127.0.0.1:7000 -s 100 -i 50_000_000 \
--ponythreads=1 -y -g 12 -w -u -m 10000
```

Then once giles sender is finished, terminate `sequence_window` with `Ctrl-C`.
Note that the last output from the sequence_window application shows "[9997,
9998, 9999, 10000]".
Restart `sequence_window`, and wait for it to complete its recovery process.

Send one more message with giles sender:
```bash
../../../../giles/sender/sender -h 127.0.0.1:7000 -s 100 -i 50_000_000 \
--ponythreads=1 -y -g -12 -w -u -m 2 -v 10000
```

The application's output should show the sequence "[9995, 9997, 9999, 10001]"
and "[9996, 9998, 10000, 10002]" on the two workers respectively,
ndicating that the last state before termination was restored succesfully, and
that the application resumed the sequence_window functionality correctly.

To test this output automatically, use the validator app:
```bash
validator/validator -i recived.txt -e 10002
```
"""

use "assert"
use "buffered"
use "collections"
use "ring"
use "serialise"
use "wallaroo_labs/bytes"
use "wallaroo"
use "wallaroo/core/common"
use "wallaroo_labs/mort"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/state"
use "wallaroo/core/topology"
use "window_codecs"

actor Main
  new create(env: Env) =>
    try
      let pipeline = recover val
        let inputs = Wallaroo.source[U64]("Sequence Window",
            TCPSourceConfig[U64 val].from_options(U64FramedHandler,
              TCPSourceConfigCLIParser(env.args)?("Sequence Window")?))

        inputs
          .collect()
          .to[U64](MaybeOneToMany)
          .key_by(ExtractWindow)
          .to[String val](ObserveNewValue)
          .to_sink(TCPSinkConfig[String val].from_options(WindowEncoder,
              TCPSinkConfigCLIParser(env.args)?(0)?))
      end

      Wallaroo.build_application(env, "Sequence Window Printer", pipeline)
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

primitive ExtractWindow
  fun apply(u: U64 val): Key =>
    // Always use the same partition
    (u % 2).string()

primitive MaybeOneToMany is StatelessComputation[U64, U64]
  """
  Possibly one to many this message.

  The goal is to keep a continous sequence of incrementing U64s.
  Every Xth number, we will send that number plus the next two numbers as a
  "one to many" message. We then filter the next to numbers when we come to
  them. This allows for us to test with a "normal" sequence window test that
  both "1 to 1" and "1 to many" work correctly.
  """
  fun name(): String =>
    "I might one to many this message!"

  fun apply(input: U64): (U64 | Array[U64] val | None) =>
    let magic_number = U64(12)
    if input < magic_number then
      // start our sneaky logic at "magic_number".
      // Of we start before "magic_number, then we will skip
      // 1 and 2 which isn't what we want
      input
    else
      let mod_magic = input % magic_number
      if mod_magic == 0 then
        recover val [input; input + 1; input + 2] end
      elseif (mod_magic == 1) or (mod_magic == 2) then
        None
      else
        input
      end
    end

class WindowState is State
  var ring: Ring[U64] = Ring[U64].from_array(recover [0; 0; 0; 0] end, 4, 0)

  fun string(): String =>
    try
      ring.string(where fill = "0")?
    else
      "Error: failed to convert sequence window into a string."
    end

  fun ref push(u: U64) =>
    ring.push(u)

    ifdef "validate" then
      try
        // Test validity of updated window
        let values = to_array()
        Fact(TestIncrements(values), "Increments test failed on " +
          string())?
      else
        Fail()
      end
    end

  fun to_array(): Array[U64] val =>
    let ar: Array[U64] iso = recover Array[U64](4) end
    for v in ring.values() do
      ar.push(v)
    end
    ar.reverse_in_place()
    consume ar

primitive ObserveNewValue is StateComputation[U64 val, String val, WindowState]
  fun name(): String => "Observe new value"

  fun apply(u: U64 val, state: WindowState): String val =>
    state.push(u)
    state.string()

  fun initial_state(): WindowState =>
    WindowState
