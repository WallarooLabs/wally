"""
WActor Creator App

1) reports sink:

```bash
nc -l 127.0.0.1 5555 >> /dev/null
```

2) metrics sink:

```bash
nc -l 127.0.0.1 5001 >> /dev/null
```

3a) 1 worker:

```bash
./w_actor_creator --in 127.0.0.1:7000 --out 127.0.0.1:5555 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --name node-name --ponythreads=4 --ponynoblock
```

3b) 2 workers:

```bash
./w_actor_creator --in 127.0.0.1:7000 --out 127.0.0.1:5555 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --name node-name --ponythreads=4 --ponynoblock --worker-count 2 \
  --topology-initializer

./w_actor_creator --in 127.0.0.1:7001 --out 127.0.0.1:5555 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 --name worker2 --ponythreads=4 --ponynoblock --worker-count 2
```

4) sender

```bash
giles/sender/sender --host 127.0.0.1:7000 --batch-size 100 --interval \
  50_000_000 --messages 1000 --binary --msg-size 12 --u64 --ponythreads=1 \
  --no-write
```

A successful run should print:

```
Run succeeded: Created actor got a msg from x!
```

where x is the creator WActor's id.

"""
use "assert"
use "buffered"
use "collections"
use pers = "collections/persistent"
use "net"
use "random"
use "time"
use "sendence/bytes"
use "sendence/fix"
use "sendence/guid"
use "sendence/hub"
use "sendence/new_fix"
use "sendence/options"
use "sendence/rand"
use "sendence/time"
use "wallaroo"
use "wallaroo/fail"
use "wallaroo/metrics"
use "wallaroo/source/tcp_source"
use "wallaroo/topology"
use "wallaroo/ent/w_actor"

primitive Roles
  fun created(): String => "created"

actor Main
  new create(env: Env) =>
    let seed: U64 = 12345
    let actor_count: USize = 1
    let actor_system = create_actors(seed)
    ActorSystemStartup(env, actor_system, "actor-creator-app")

  fun ref create_actors(init_seed: U64): ActorSystem val =>
    recover
      ActorSystem("ActorSystem Creator App", init_seed)
        .>add_source(SimulationFramedSourceHandler, IngressWActorRouter)
        .>add_actor(CreatorBuilder)
    end

class Creator is WActor
  var done_creating: Bool = false
  var count: USize = 0

  new create(h: WActorHelper) =>
    h.register_as_role(BasicRoles.ingress())

  fun ref receive(sender: U128, payload: Any val, h: WActorHelper) =>
    None

  fun ref process(data: Any val, h: WActorHelper) =>
    if not done_creating then
      h.create_actor(CreatedBuilder)
      h.create_actor(EmptyABuilder)
      h.send_to_role(Roles.created(), "Hi")
      done_creating = true
    end

class Created is WActor
  new create(h: WActorHelper) =>
    h.register_as_role(Roles.created())

  fun ref receive(sender: U128, payload: Any val, h: WActorHelper) =>
    @printf[I32]("Run succeeded: Created actor got a msg from %s! \n"
      .cstring(), sender.string().cstring())

  fun ref process(data: Any val, h: WActorHelper) =>
    None

class EmptyA is WActor
  new create(h: WActorHelper) =>
    None

  fun ref receive(sender: U128, payload: Any val, h: WActorHelper) =>
    None

  fun ref process(data: Any val, h: WActorHelper) =>
    None

primitive CreatorBuilder
  fun apply(id: U128, wh: WActorHelper): WActor =>
    Creator(wh)

primitive CreatedBuilder
  fun apply(id: U128, wh: WActorHelper): WActor =>
    Created(wh)

primitive EmptyABuilder
  fun apply(id: U128, wh: WActorHelper): WActor =>
    EmptyA(wh)
