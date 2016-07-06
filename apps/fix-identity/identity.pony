use "net"
use "collections"
use "buffy"
use "buffy/messages"
use "buffy/metrics"
use "buffy/topology"
use "sendence/fix"

actor Main
  new create(env: Env) =>
    try
      let topology: Topology val = recover val
        Topology
          .new_pipeline[FixOrderMessage val, FixOrderMessage val](TradeParser, TradeS, recover [0] end, "Identity")
          .to[FixOrderMessage val](lambda(): Computation[FixOrderMessage val, FixOrderMessage val] iso^ => Identity end)
          .to[FixOrderMessage val](lambda(): Computation[FixOrderMessage val, FixOrderMessage val] iso^ => Identity end)
          .build()
      end
      Startup(env, topology, 1)
    else
      env.out.print("Couldn't build topology")
    end

class Identity is Computation[FixOrderMessage val, FixOrderMessage val]
  fun name(): String => "identity"
  fun apply(d: FixOrderMessage val): FixOrderMessage val =>
    d

class P
  fun apply(s: String): String =>
    s

class TradeParser is Parser[FixOrderMessage val]
  fun apply(s: String): (FixOrderMessage val | None) =>
    // FixOrderMessage(Buy, "", "", "", 1.0, 1.0, "")
    match FixParser(s)
    | let m: FixOrderMessage val => m
    else
      None
    end

class S
  fun apply(input: String): String =>
    input

primitive TradeS
  fun apply(input: FixOrderMessage val): String =>
    ""

