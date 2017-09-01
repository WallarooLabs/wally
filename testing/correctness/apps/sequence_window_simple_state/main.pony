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
1. Giles receiver:
```bash
../../../../giles/receiver/receiver --ponythreads=1 --ponynoblock \
--ponypinasio -l 127.0.0.1:5555
```
2. Initializer worker
```bash
./sequence_window_simple_state -i 127.0.0.1:7000 -o 127.0.0.1:5555 -m 127.0.0.1:5001 \
--ponythreads=4 --ponypinasio --ponynoblock -c 127.0.0.1:12500 \
-d 127.0.0.1:12501 -r res-data -w 2 -n worker1 -t
```
3. Second worker
```bash
./sequence_window_simple_state -i 127.0.0.1:7000 -o 127.0.0.1:5555 -m 127.0.0.1:5001 \
--ponythreads=4 --ponypinasio --ponynoblock -c 127.0.0.1:12500 \
-r res-data -n worker2
```
4. Sender
```bash
../../../../giles/sender/sender -b 127.0.0.1:7000 -s 100 -i 50_000_000 \
--ponythreads=1 -y -g 12 -w -u -m 10000
```

Then once giles sender is finished, terminate `sequence_window` with `Ctrl-C`.
Note that the last output from the sequence_window application shows "[9997,
9998, 9999, 10000]".
Restart `sequence_window`, and wait for it to complete its recovery process.

Send one more message with giles sender:
```bash
../../../../giles/sender/sender -b 127.0.0.1:7000 -s 100 -i 50_000_000 \
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

use "buffered"
use "collections"
use "ring"
use "serialise"
use "sendence/bytes"
use "wallaroo/"
use "wallaroo/fail"
use "wallaroo/sink/tcp_sink"
use "wallaroo/source"
use "wallaroo/source/tcp_source"
use "wallaroo/state"
use "wallaroo/topology"
use "window_codecs"

actor Main
  new create(env: Env) =>
    try
      let part_ar: Array[(U64, USize)] val = recover
        let pa = Array[(U64, USize)]
        pa.push((0,0))
        pa.push((1,1))
        consume pa
      end
      let partition = Partition[U64, U64](WindowPartitionFunction, part_ar)

      let application = recover val
        Application("Sequence Window Printer")
          .new_pipeline[U64 val, String val]("Sequence Window",
            TCPSourceConfig[U64 val].from_options(U64FramedHandler,
              TCPSourceConfigCLIParser(env.args)(0)))
          .to_state_partition[U64 val, U64 val, String val,
            WindowState](ObserveNewValue, WindowStateBuilder, "window-state",
              partition where multi_worker = true)
          .to_sink(TCPSinkConfig[String val].from_options(WindowEncoder,
              TCPSinkConfigCLIParser(env.args)(0)))
      end
      Startup(env, application, "sequence_window")
    else
      env.out.print("Couldn't build topology")
    end

primitive WindowPartitionFunction
  fun apply(u: U64 val): U64 =>
    // Always use the same partition
    u % 2

class val WindowStateBuilder
  fun apply(): WindowState => WindowState
  fun name(): String => "Window State"

class WindowState is State
  var idx: USize = 0
  var ring: Ring[U64] = Ring[U64].from_array(recover [0,0,0,0] end, 4, 0)

  fun string(): String =>
    try
      ring.string(where fill = "0")
    else
      "Error: failed to convert sequence window into a string."
    end

  fun ref push(u: U64) =>
    ring.push(u)
    idx = idx + 1

primitive ObserveNewValue is StateComputation[U64 val, String val, WindowState]
  fun name(): String => "Observe new value"

  fun apply(u: U64 val,
    sc_repo: StateChangeRepository[WindowState],
    state: WindowState): (String val, DirectStateChange)
  =>
    state.push(u)

    (state.string(), DirectStateChange)

  fun state_change_builders():
    Array[StateChangeBuilder[WindowState]] val
  =>
    recover Array[StateChangeBuilder[WindowState]] end
