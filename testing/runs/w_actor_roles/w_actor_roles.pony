"""
WActor Role Checking App

1) reports sink:

```
nc -l 127.0.0.1 5555 >> /dev/null
```

2) metrics sink:

```
nc -l 127.0.0.1 5001 >> /dev/null
```

3a) 1 worker:

```bash
./w_actor_roles --in 127.0.0.1:7000 --out 127.0.0.1:5555 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --name node-name --ponythreads=4 --ponynoblock
```

3b) 2 workers:

```bash
./w_actor_roles --in 127.0.0.1:7000 --out 127.0.0.1:5555 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --name node-name --ponythreads=4 --ponynoblock --worker-count 2 \
  --topology-initializer

./w_actor_roles --in 127.0.0.1:7001 --out 127.0.0.1:5555 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 --name worker2 --ponythreads=4 --ponynoblock --worker-count 2
```

4) sender

```bash
giles/sender/sender --host 127.0.0.1:7000 --batch-size 100 --interval \
  50_000_000 --messages 1000 --binary --msg-size 12 --u64 --ponythreads=1 \
  --no-write
```

Correct output:
A sequence of messages outputted of the form

```
x_role rcvd msg from y_role
```

where x and y can be the same or different from among "first", "second", and
"third"
```

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
use "wallaroo/tcp_source"
use "wallaroo/topology"
use "wallaroo/ent/w_actor"


primitive Roles
  fun first_role(): String => "first_role"
  fun second_role(): String => "second_role"
  fun third_role(): String => "third_role"

actor Main
  new create(env: Env) =>
    let seed: U64 = 12345
    let actor_count: USize = 10
    let iterations: USize = 100
    let actor_system = create_actors(actor_count, iterations, seed)
    ActorSystemStartup(env, actor_system, "toy-model-CRDT-app")

  fun ref create_actors(n: USize, iterations: USize, init_seed: U64):
    ActorSystem val
  =>
    recover
      let rand = EnhancedRandom(init_seed)
      let actor_system =
        ActorSystem("Role Lookup App", rand.u64())
          .> add_source(SimulationFramedSourceHandler, IngressWActorRouter)
          .> add_actor(ABuilder(Roles.first_role(), rand.u64()))
          .> add_actor(ABuilder(Roles.second_role(), rand.u64()))
          .> add_actor(ABuilder(Roles.third_role(), rand.u64()))

      actor_system
    end

class A is WActor
  let _id: U64
  let _role: String
  let _rand: EnhancedRandom

  new create(h: WActorHelper, role': String, id': U64, seed: U64) =>
    _role = role'
    h.register_as_role(_role)
    h.register_as_role(BasicRoles.ingress())
    _id = id'
    _rand = EnhancedRandom(seed)

  fun ref receive(sender: U128, payload: Any val, h: WActorHelper) =>
    try
      let roles = h.roles_for(sender)
      @printf[I32]("%s rcvd msg from %s\n".cstring(), _role.cstring(),
        roles(0).cstring())
    else
      @printf[I32]("Couldn't find role for %s\n".cstring(),
        sender.string().cstring())
    end

  fun ref process(data: Any val, h: WActorHelper) =>
    match data
    | Act =>
      act(h)
    end

  fun ref act(h: WActorHelper) =>
    match _rand.usize_between(1, 3)
    | 1 => h.send_to_role(Roles.first_role(), "1")
    | 2 => h.send_to_role(Roles.second_role(), "2")
    | 3 => h.send_to_role(Roles.third_role(), "3")
    end

class ABuilder
  let _role: String
  let _seed: U64

  new val create(role: String = "", seed: U64) =>
    _role = role
    _seed = seed

  fun apply(id: U128, wh: WActorHelper): WActor =>
    let short_id = (id >> 96).u64()
    A(wh, _role, short_id, _seed)
