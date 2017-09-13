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
## Generating Data

A data generator is bundled with the application. It needs to be built:

```bash
stable env ponyc ./data_gen
```

Then you can generate a file with a fixed number of values:
```
./data_gen1 -m 10000
```

This will create a `celsius.msg` file in your current working directory.

## Running Celsius

In a separate shell, each:

0. In a shell, start up the Metrics UI if you don't already have it running:
    ```bash
    docker start mui
    ```
1. Start a listener
    ```bash
    nc -l 127.0.0.1 7002 > celsius.out
    ```
2. Start the application
    ```bash
    ./w_actor_celsius -i 127.0.0.1:7010 -o 127.0.0.1:7002
    ```
3. Start a sender
    ```bash
    ../../../giles/sender/sender --host 127.0.0.1:7010 --file celsius.msg \
      --batch-size 5 --interval 100_000_000 --messages 150 --binary \
      --variable-size --repeat --ponythreads=1 --no-write
    ```

"""
use "assert"
use "buffered"
use "collections"
use pers = "collections/persistent"
use "net"
use "random"
use "time"
use "wallaroo_labs/bytes"
use "wallaroo_labs/fix"
use "wallaroo_labs/guid"
use "wallaroo_labs/hub"
use "wallaroo_labs/new_fix"
use "wallaroo_labs/options"
use "wallaroo_labs/rand"
use "wallaroo_labs/time"
use "wallaroo"
use "wallaroo/ent/w_actor"
use "wallaroo/core/fail"
use "wallaroo/core/metrics"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/topology"

actor Main
  new create(env: Env) =>
    let seed: U64 = 12345
    let actor_system = create_actors(seed)
    ActorSystemStartup(env, actor_system, "actor-system-celsius-app")

  fun ref create_actors(init_seed: U64): ActorSystem val
  =>
    recover
      ActorSystem("ActorSystem Celsius App", init_seed)
        .> add_source(CelsiusDecoder, IngressWActorRouter)
        .> add_actor(CelsiusBuilder)
        .add_sink[F32](TCPSinkConfig[F32](FahrenheitEncoder, "127.0.0.1",
          "5555"))
    end

class Celsius is WActor
  new create(h: WActorHelper) =>
    h.register_as_role(BasicRoles.ingress())

  fun ref receive(sender: U128, payload: Any val, h: WActorHelper) =>
    None

  fun ref process(data: Any val, h: WActorHelper) =>
    match data
    | let f: F32 =>
      let c = (f * 1.8) + 32
      h.send_to_sink[F32](0, c)
    end

primitive CelsiusBuilder
  fun apply(id: U128, wh: WActorHelper): WActor =>
    Celsius(wh)

primitive CelsiusDecoder is FramedSourceHandler[F32]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize =>
    4

  fun decode(data: Array[U8] val): F32 ? =>
    Bytes.to_f32(data(0), data(1), data(2), data(3))

primitive FahrenheitEncoder
  fun apply(f: F32, wb: Writer): Array[ByteSeq] val =>
    @printf[I32]("%s\n".cstring(), f.string().cstring())
    wb.f32_be(f)
    wb.done()
