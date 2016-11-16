"""
Market Spread App

Setting up a market spread run (in order):
1) reports sink (if not using Monitoring Hub):
nc -l 127.0.0.1 5555 >> /dev/null

2) metrics sink (if not using Monitoring Hub):
nc -l 127.0.0.1 5001 >> /dev/null

3a) market spread app (1 worker):
./market-test -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -e 10000000 -n node-name --ponythreads=4 --ponynoblock

3b) market spread app (2 workers):
./market-test -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -e 10000000 -n node-name --ponythreads=4 --ponynoblock -t -w 2

./market-test -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -e 10000000 -n worker2 --ponythreads=4 --ponynoblock -w 2

4) initial nbbo data:
giles/sender/sender -b 127.0.0.1:7000 -m 1000 -s 300 -i 2_500_000 -f demos/marketspread/initial-nbbo-fixish.msg --ponythreads=1 -y -g 46 -w

5) orders:
giles/sender/sender -b 127.0.0.1:7001 -m 5000000 -s 300 -i 5_000_000 -f demos/marketspread/350k-orders-fixish.msg -r --ponythreads=1 -y -g 57 -w

6) nbbo:
giles/sender/sender -b 127.0.0.1:7000 -m 10000000 -s 300 -i 2_500_000 -f demos/marketspread/350k-nbbo-fixish.msg -r --ponythreads=1 -y -g 46 -w
"""
use "collections"
use "net"
use "options"
use "time"
use "buffered"
use "files"
use "sendence/bytes"
use "sendence/fix"
use "sendence/new-fix"
use "sendence/hub"
use "sendence/epoch"
use "wallaroo"
use "wallaroo/backpressure"
use "wallaroo/boundary"
use "wallaroo/initialization"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/network"
use "wallaroo/resilience"
use "wallaroo/tcp-sink"
use "wallaroo/tcp-source"
use "wallaroo/topology"

actor Main
  new create(env: Env) =>
    var m_arg: (Array[String] | None) = None
    var o_arg: (Array[String] | None) = None
    var c_arg: (Array[String] | None) = None
    var d_arg: (Array[String] | None) = None
    var p_arg: (Array[String] | None) = None
    var i_addrs_write: Array[Array[String]] trn =
      recover Array[Array[String]] end
    var worker_count: USize = 1
    var is_initializer = false
    var worker_initializer: (WorkerInitializer | None) = None
    let alfred = Alfred(env, None)
    var worker_name = ""
    try
      var options = Options(env.args)
      var auth = env.root as AmbientAuth

      options
        .add("expected", "e", I64Argument)
        .add("metrics", "m", StringArgument)
        .add("in", "i", StringArgument)
        .add("out", "o", StringArgument)
        .add("control", "c", StringArgument)
        .add("data", "d", StringArgument)
        .add("phone-home", "p", StringArgument)
        .add("file", "f", StringArgument)
        // worker count includes the initial "leader" since there is no
        // persisting leader
        .add("worker-count", "w", I64Argument)
        .add("topology-initializer", "t", None)
        .add("leader", "l", None)
        .add("name", "n", StringArgument)

      for option in options do
        match option
        | ("expected", let arg: I64) =>
          env.out.print("--expected/-e is a deprecated parameter")
        | ("metrics", let arg: String) => m_arg = arg.split(":")
        | ("in", let arg: String) =>
          for addr in arg.split(",").values() do
            i_addrs_write.push(addr.split(":"))
          end
        | ("out", let arg: String) => o_arg = arg.split(":")
        | ("control", let arg: String) => c_arg = arg.split(":")
        | ("data", let arg: String) => d_arg = arg.split(":")
        | ("phone-home", let arg: String) => p_arg = arg.split(":")
        | ("file", let arg: String) =>
          env.out.print("--file/-f is a deprecated parameter")
        | ("worker-count", let arg: I64) =>
          worker_count = arg.usize()
        | ("topology-initializer", None) => is_initializer = true
        | ("name", let arg: String) => worker_name = arg
        end
      end

      if worker_count == 1 then is_initializer = true end

      if is_initializer then worker_name = "initializer" end

      let input_addrs: Array[Array[String]] val = consume i_addrs_write
      let m_addr = m_arg as Array[String]
      let c_addr = c_arg as Array[String]
      let c_host = c_addr(0)
      let c_service = c_addr(1)

      let o_addr_ref = o_arg as Array[String]
      let o_addr_trn: Array[String] trn = recover Array[String] end
      o_addr_trn.push(o_addr_ref(0))
      o_addr_trn.push(o_addr_ref(1))
      let o_addr: Array[String] val = consume o_addr_trn

      let d_addr_ref = d_arg as Array[String]
      let d_addr_trn: Array[String] trn = recover Array[String] end
      d_addr_trn.push(d_addr_ref(0))
      d_addr_trn.push(d_addr_ref(1))
      let d_addr: Array[String] val = consume d_addr_trn

      let d_host = d_addr(0)
      let d_service = d_addr(1)

      if worker_name == "" then
        env.out.print("You must specify a worker name via --worker-name/-n.")
        error
      end

      let connect_auth = TCPConnectAuth(auth)
      let metrics_conn = TCPConnection(connect_auth,
          OutNotify("metrics"),
          m_addr(0),
          m_addr(1))

      let connect_msg = HubProtocol.connect()
      let metrics_join_msg = HubProtocol.join("metrics:Market Spread App")
      metrics_conn.writev(connect_msg)
      metrics_conn.writev(metrics_join_msg)

      (let ph_host, let ph_service) =
        match p_arg
        | let addr: Array[String] =>
          (addr(0), addr(1))
        else
          ("", "")
        end


      // SINK
      let encoder_wrapper = TypedEncoderWrapper[OrderResult val](
        OrderResultEncoder)

      let sink_reporter = MetricsReporter("Market Spread App",
        metrics_conn)

      let initial_report_msgs_trn: Array[Array[ByteSeq] val] trn =
        recover Array[Array[ByteSeq] val] end
      let report_connect_msg = HubProtocol.connect()
      let join_msg = HubProtocol.join("reports:market-spread")
      initial_report_msgs_trn.push(report_connect_msg)
      initial_report_msgs_trn.push(join_msg)
      let initial_report_msgs: Array[Array[ByteSeq] val] val =
        consume initial_report_msgs_trn

      let sink = TCPSink(encoder_wrapper, consume sink_reporter,
        o_addr(0),
        o_addr(1),
        initial_report_msgs)

      let sink_router = DirectRouter(sink)


      // STATE PARTITION

      let state_runner_builder = StateRunnerBuilder[SymbolData](
        SymbolDataBuilder, "Symbol Data", UpdateNbbo.state_change_builders())

      let state_subpartition = KeyedStateSubpartition[String](
        LegalSymbols.symbols, state_runner_builder
        where multi_worker = false)

      let state_addresses = state_subpartition.build("Market Spread App",
        metrics_conn, alfred)


      // NBBO SOURCE

      let nbbo_partition_router = StateAddressesRouter[FixNbboMessage val,
        String](state_addresses, SymbolPartitionFunction)

      let nbbo_runner_builder = PreStateRunnerBuilder[FixNbboMessage val, None,
        SymbolData](UpdateNbbo,
          TypedRouteBuilder[StateProcessor[SymbolData] val],
          TypedRouteBuilder[None])

      let nbbo_route_builder =
        TypedRouteBuilder[StateProcessor[SymbolData] val]

      let nbbo_s_s_builder = TypedSourceBuilderBuilder[FixNbboMessage val](
        "Market Spread App", "NBBO Source", FixNbboFrameHandler)

      TCPSourceListener(
        nbbo_s_s_builder(nbbo_runner_builder,
          nbbo_partition_router, metrics_conn),
        nbbo_partition_router,
        nbbo_route_builder,
        recover Map[String, OutgoingBoundary] end,
        alfred, None, EmptyRouter,
        input_addrs(0)(0),
        input_addrs(0)(1))


      // ORDERS SOURCE

      let orders_partition_router = StateAddressesRouter[FixOrderMessage val,
        String](state_addresses, SymbolPartitionFunction)

      let orders_runner_builder = PreStateRunnerBuilder[FixOrderMessage val, OrderResult val, SymbolData](CheckOrder,
          TypedRouteBuilder[StateProcessor[SymbolData] val],
          TypedRouteBuilder[OrderResult val])

      let orders_route_builder =
        TypedRouteBuilder[StateProcessor[SymbolData] val]

      let orders_s_s_builder = TypedSourceBuilderBuilder[FixOrderMessage val](
        "Market Spread App", "Orders Source", FixOrderFrameHandler)

      TCPSourceListener(
        orders_s_s_builder(orders_runner_builder,
          orders_partition_router, metrics_conn),
        orders_partition_router,
        orders_route_builder,
        recover Map[String, OutgoingBoundary] end,
        alfred, None, sink_router,
        input_addrs(1)(0),
        input_addrs(1)(1))

      // Register leftover routes

      state_addresses.register_routes(sink_router, TypedRouteBuilder[OrderResult val])
    end







      // let connections = Connections(application.name(), worker_name, env, auth,
      //   c_host, c_service, d_host, d_service, ph_host, ph_service,
      //   metrics_conn, is_initializer)

      // let local_topology_file = "/tmp/" + worker_name + ".local-topology"
      // let local_topology_initializer = LocalTopologyInitializer(worker_name,
      //   worker_count, env, auth, connections, metrics_conn, is_initializer,
      //   alfred, local_topology_file)

      // if is_initializer then
      //   env.out.print("Running as Initializer...")
      //   let application_initializer = ApplicationInitializer(auth,
      //     local_topology_initializer, input_addrs, o_addr, alfred)

      //   worker_initializer = WorkerInitializer(auth, worker_count, connections,
      //     application_initializer, local_topology_initializer, d_addr,
      //     metrics_conn)
      //   worker_name = "initializer"
      // end

      // let control_notifier: TCPListenNotify iso =
      //   ControlChannelListenNotifier(worker_name, env, auth, connections,
      //     is_initializer, worker_initializer, local_topology_initializer, alfred)

      // if is_initializer then
      //   connections.register_listener(
      //     TCPListener(auth, consume control_notifier, c_host, c_service)
      //   )
      // else
      //   connections.register_listener(
      //     TCPListener(auth, consume control_notifier)
      //   )
      // end

      // match worker_initializer
      // | let w: WorkerInitializer =>
      //   w.start(application)
      // end


primitive Identity[In: Any val]
  fun name(): String => "identity"
  fun apply(r: In): In =>
    // @printf[I32]("Identity!!\n".cstring())
    r

primitive IdentityBuilder[In: Any val]
  fun apply(): Computation[In, In] val =>
    Identity[In]


interface Symboly
  fun symbol(): String

class val SymbolDataBuilder
  fun apply(): SymbolData => SymbolData
  fun name(): String => "Market Data"

class SymbolData
  var should_reject_trades: Bool = true
  var last_bid: F64 = 0
  var last_offer: F64 = 0

class SymbolDataStateChange is StateChange[SymbolData]
  let _id: U64
  let _name: String
  var _should_reject_trades: Bool = false
  var _last_bid: F64 = 0
  var _last_offer: F64 = 0

  fun name(): String => _name
  fun id(): U64 => _id

  new create(id': U64, name': String) =>
    _id = id'
    _name = name'

  fun ref update(should_reject_trades: Bool, last_bid: F64, last_offer: F64) =>
    _should_reject_trades = should_reject_trades
    _last_bid = last_bid
    _last_offer = last_offer

  fun apply(state: SymbolData ref) =>
    // @printf[I32]("State change!!\n".cstring())
    state.last_bid = _last_bid
    state.last_offer = _last_offer
    state.should_reject_trades = _should_reject_trades

  fun write_log_entry(out_writer: Writer) =>
    out_writer.f64_be(_last_bid)
    out_writer.f64_be(_last_offer)
    out_writer.bool(_should_reject_trades)

  fun ref read_log_entry(in_reader: Reader) ? =>
    _last_bid = in_reader.f64_be()
    _last_offer = in_reader.f64_be()
    _should_reject_trades = in_reader.bool()

class SymbolDataStateChangeBuilder is StateChangeBuilder[SymbolData]
  fun apply(id: U64): StateChange[SymbolData] =>
    SymbolDataStateChange(id, "SymbolDataStateChange")

primitive UpdateNbbo is StateComputation[FixNbboMessage val, None, SymbolData]
  fun name(): String => "Update NBBO"

  fun apply(msg: FixNbboMessage val,
    sc_repo: StateChangeRepository[SymbolData],
    state: SymbolData): (None, StateChange[SymbolData] ref)
  =>
    // @printf[I32]("!!Update NBBO\n".cstring())
    let state_change: SymbolDataStateChange ref =
      try
        sc_repo.lookup_by_name("SymbolDataStateChange") as SymbolDataStateChange
      else
        //TODO: ideally, this should also register it. Not sure how though.
        SymbolDataStateChange(0, "SymbolDataStateChange")
      end
    let offer_bid_difference = msg.offer_px() - msg.bid_px()

    let should_reject_trades = (offer_bid_difference >= 0.05) or
      ((offer_bid_difference / msg.mid()) >= 0.05)

    state_change.update(should_reject_trades, msg.bid_px(), msg.offer_px())
    (None, state_change)

  fun state_change_builders(): Array[StateChangeBuilder[SymbolData] val] val =>
    recover val
      let scbs = Array[StateChangeBuilder[SymbolData] val]
      scbs.push(recover val SymbolDataStateChangeBuilder end)
    end

class CheckOrder is StateComputation[FixOrderMessage val, OrderResult val,
  SymbolData]
  fun name(): String => "Check Order against NBBO"

  fun apply(msg: FixOrderMessage val,
    sc_repo: StateChangeRepository[SymbolData],
    state: SymbolData): ((OrderResult val | None), None)
  =>
    // @printf[I32]("!!CheckOrder\n".cstring())
    if state.should_reject_trades then
      let res = OrderResult(msg, state.last_bid, state.last_offer,
        Epoch.nanoseconds())
      (res, None)
    else
      (None, None)
    end

  fun state_change_builders(): Array[StateChangeBuilder[SymbolData] val] val =>
    recover val
      Array[StateChangeBuilder[SymbolData] val]
    end

primitive FixOrderFrameHandler is FramedSourceHandler[FixOrderMessage val]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

  fun decode(data: Array[U8] val): FixOrderMessage val ? =>
    match FixishMsgDecoder(data)
    | let m: FixOrderMessage val => m
    else
      error
    end

primitive FixNbboFrameHandler is FramedSourceHandler[FixNbboMessage val]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

  fun decode(data: Array[U8] val): FixNbboMessage val ? =>
    match FixishMsgDecoder(data)
    | let m: FixNbboMessage val => m
    else
      // @printf[I32]("Could not get FixNbbo from incoming data\n".cstring())
      error
    end

primitive SymbolPartitionFunction
  fun apply(input: Symboly val): String
  =>
    input.symbol()

class OrderResult
  let order: FixOrderMessage val
  let bid: F64
  let offer: F64
  let timestamp: U64

  new val create(order': FixOrderMessage val,
    bid': F64,
    offer': F64,
    timestamp': U64)
  =>
    order = order'
    bid = bid'
    offer = offer'
    timestamp = timestamp'

  fun string(): String =>
    (order.symbol().clone().append(", ")
      .append(order.order_id()).append(", ")
      .append(order.account().string()).append(", ")
      .append(order.price().string()).append(", ")
      .append(order.order_qty().string()).append(", ")
      .append(order.side().string()).append(", ")
      .append(bid.string()).append(", ")
      .append(offer.string()).append(", ")
      .append(timestamp.string())).clone()

primitive OrderResultEncoder
  fun apply(r: OrderResult val, wb: Writer = Writer): Array[ByteSeq] val =>
    //@printf[I32](("!!" + r.order.order_id() + " " + r.order.symbol() + "\n").cstring())
    //Header (size == 55 bytes)
    let msgs_size: USize = 1 + 4 + 6 + 4 + 8 + 8 + 8 + 8 + 8
    wb.u32_be(msgs_size.u32())
    //Fields
    match r.order.side()
    | Buy => wb.u8(SideTypes.buy())
    | Sell => wb.u8(SideTypes.sell())
    end
    wb.u32_be(r.order.account())
    wb.write(r.order.order_id().array()) // assumption: 6 bytes
    wb.write(r.order.symbol().array()) // assumption: 4 bytes
    wb.f64_be(r.order.order_qty())
    wb.f64_be(r.order.price())
    wb.f64_be(r.bid)
    wb.f64_be(r.offer)
    wb.u64_be(r.timestamp)
    let payload = wb.done()
    HubProtocol.payload("rejected-orders", "reports:market-spread",
      consume payload, wb)

class LegalSymbols
  let symbols: Array[String] val

  new create() =>
    let padded: Array[String] trn = recover Array[String] end
    for symbol in RawSymbols().values() do
      padded.push(RawSymbols.pad_symbol(symbol))
    end
    symbols = consume padded

primitive RawSymbols
  fun pad_symbol(s: String): String =>
    if s.size() == 4 then
      s
    else
      let diff = 4 - s.size()
      var padded = s
      for i in Range(0, diff) do
        padded = " " + padded
      end
      padded
    end

  fun apply(): Array[String] val =>
    recover
      [
"AA",
"BAC",
"AAPL",
"FCX",
"SUNE",
"FB",
"RAD",
"INTC",
"GE",
"WMB",
"S",
"ATML",
"YHOO",
"F",
"T",
"MU",
"PFE",
"CSCO",
"MEG",
"HUN",
"GILD",
"MSFT",
"SIRI",
"SD",
"C",
"NRF",
"TWTR",
"ABT",
"VSTM",
"NLY",
"AMAT",
"X",
"NFLX",
"SDRL",
"CHK",
"KO",
"JCP",
"MRK",
"WFC",
"XOM",
"KMI",
"EBAY",
"MYL",
"ZNGA",
"FTR",
"MS",
"DOW",
"ATVI",
"ORCL",
"JPM",
"FOXA",
"HPQ",
"JBLU",
"RF",
"CELG",
"HST",
"QCOM",
"AKS",
"EXEL",
"ABBV",
"CY",
"VZ",
"GRPN",
"HAL",
"GPRO",
"CAT",
"OPK",
"AAL",
"JNJ",
"XRX",
"GM",
"MHR",
"DNR",
"PIR",
"MRO",
"NKE",
"MDLZ",
"V",
"HLT",
"TXN",
"SWN",
"AGN",
"EMC",
"CVX",
"BMY",
"SLB",
"SBUX",
"NVAX",
"ZIOP",
"NE",
"COP",
"EXC",
"OAS",
"VVUS",
"BSX",
"SE",
"NRG",
"MDT",
"WFM",
"ARIA",
"WFT",
"MO",
"PG",
"CSX",
"MGM",
"SCHW",
"NVDA",
"KEY",
"RAI",
"AMGN",
"HTZ",
"ZTS",
"USB",
"WLL",
"MAS",
"LLY",
"WPX",
"CNW",
"WMT",
"ASNA",
"LUV",
"GLW",
"BAX",
"HCA",
"NEM",
"HRTX",
"BEE",
"ETN",
"DD",
"XPO",
"HBAN",
"VLO",
"DIS",
"NRZ",
"NOV",
"MET",
"MNKD",
"MDP",
"DAL",
"XON",
"AEO",
"THC",
"AGNC",
"ESV",
"FITB",
"ESRX",
"BKD",
"GNW",
"KN",
"GIS",
"AIG",
"SYMC",
"OLN",
"NBR",
"CPN",
"TWO",
"SPLS",
"AMZN",
"UAL",
"MRVL",
"BTU",
"ODP",
"AMD",
"GLNG",
"APC",
"HL",
"PPL",
"HK",
"LNG",
"CVS",
"CYH",
"CCL",
"HD",
"AET",
"CVC",
"MNK",
"FOX",
"CRC",
"TSLA",
"UNH",
"VIAB",
"P",
"AMBA",
"SWFT",
"CNX",
"BWC",
"SRC",
"WETF",
"CNP",
"ENDP",
"JBL",
"YUM",
"MAT",
"PAH",
"FINL",
"BK",
"ARWR",
"SO",
"MTG",
"BIIB",
"CBS",
"ARNA",
"WYNN",
"TAP",
"CLR",
"LOW",
"NYMT",
"AXTA",
"BMRN",
"ILMN",
"MCD",
"NAVI",
"FNFG",
"AVP",
"ON",
"DVN",
"DHR",
"OREX",
"CFG",
"DHI",
"IBM",
"HCP",
"UA",
"KR",
"AES",
"STWD",
"BRCM",
"APA",
"STI",
"MDVN",
"EOG",
"QRVO",
"CBI",
"CL",
"ALLY",
"CALM",
"SN",
"FEYE",
"VRTX",
"KBH",
"ADXS",
"HCBK",
"OXY",
"TROX",
"NBL",
"MON",
"PM",
"MA",
"HDS",
"EMR",
"CLF",
"AVGO",
"INCY",
"M",
"PEP",
"WU",
"KERX",
"CRM",
"BCEI",
"PEG",
"NUE",
"UNP",
"SWKS",
"SPW",
"COG",
"BURL",
"MOS",
"CIM",
"CLNY",
"BBT",
"UTX",
"LVS",
"DE",
"ACN",
"DO",
"LYB",
"MPC",
"SNDK",
"AGEN",
"GGP",
"RRC",
"CNC",
"PLUG",
"JOY",
"HP",
"CA",
"LUK",
"AMTD",
"GERN",
"PSX",
"LULU",
"SYY",
"HON",
"PTEN",
"NWSA",
"MCK",
"SVU",
"DSW",
"MMM",
"CTL",
"BMR",
"PHM",
"CIE",
"BRCD",
"ATW",
"BBBY",
"BBY",
"HRB",
"ISIS",
"NWL",
"ADM",
"HOLX",
"MM",
"GS",
"AXP",
"BA",
"FAST",
"KND",
"NKTR",
"ACHN",
"REGN",
"WEN",
"CLDX",
"BHI",
"HFC",
"GNTX",
"GCA",
"CPE",
"ALL",
"ALTR",
"QEP",
"NSAM",
"ITCI",
"ALNY",
"SPF",
"INSM",
"PPHM",
"NYCB",
"NFX",
"TMO",
"TGT",
"GOOG",
"SIAL",
"GPS",
"MYGN",
"MDRX",
"TTPH",
"NI",
"IVR",
"SLH"]
end
