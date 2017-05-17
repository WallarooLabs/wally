"""
Market Spread App

Setting up a market spread run (in order):
1) reports sink (if not using Monitoring Hub):
nc -l 127.0.0.1 5555 >> /dev/null

2) metrics sink (if not using Monitoring Hub):
nc -l 127.0.0.1 5001 >> /dev/null

or

giles/receiver/receiver --ponythreads=1 --ponynoblock -w -l 127.0.0.1:5555

350 Symbols

3a) market spread app (1 worker):
./market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n node-name --ponythreads=4 --ponynoblock

3b) market spread app (2 workers):
./market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n node-name --ponythreads=4 --ponynoblock -t -w 2

./market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n worker2 --ponythreads=4 --ponynoblock -w 2

4) orders:
giles/sender/sender -h 127.0.0.1:7000 -m 5000000 -s 300 -i 5_000_000 -f demos/marketspread/350k-orders-fixish.msg -r --ponythreads=1 -y -g 57 -w

5) nbbo:
giles/sender/sender -h 127.0.0.1:7001 -m 10000000 -s 300 -i 2_500_000 -f demos/marketspread/350k-nbbo-fixish.msg -r --ponythreads=1 -y -g 46 -w

R3K or other Symbol Set (700, 1400, 2100)

3a) market spread app (1 worker):
./market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n node-name -s ../../demos/marketspread/r3k-legal-symbols.msg -f ../../demos/marketspread/r3k-initial-nbbo-fixish.msg --ponythreads=4 --ponynoblock

3b) market spread app (2 workers):
./market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n node-name -s ../../demos/marketspread/r3k-legal-symbols.msg -f ../../demos/marketspread/r3k-initial-nbbo-fixish.msg --ponythreads=4 --ponynoblock -t -w 2

./market-spread -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n worker2 --ponythreads=4 --ponynoblock -w 2

4) orders:
giles/sender/sender -h 127.0.0.1:7000 -m 5000000 -s 300 -i 5_000_000 -f demos/marketspread/r3k-orders-fixish.msg -r --ponythreads=1 -y -g 57 -w

5) nbbo:
giles/sender/sender -h 127.0.0.1:7001 -m 10000000 -s 300 -i 2_500_000 -f demos/marketspread/r3k-nbbo-fixish.msg -r --ponythreads=1 -y -g 46 -w
"""
use "assert"
use "buffered"
use "collections"
use "net"
use "serialise"
use "time"
use "sendence/bytes"
use "sendence/fix"
use "sendence/hub"
use "sendence/new_fix"
use "sendence/options"
use "sendence/wall_clock"
use "wallaroo"
use "wallaroo/fail"
use "wallaroo/invariant"
use "wallaroo/metrics"
use "wallaroo/state"
use "wallaroo/tcp_source"
use "wallaroo/topology"

actor Main
  new create(env: Env) =>
    try
      var initial_nbbo_file_path =
        "../../demos/marketspread/initial-nbbo-fixish.msg"
      var symbols_file_path: (String | None) = None
      let options = Options(env.args, false)

      options
        .add("initial-nbbo-file", "f", StringArgument)
        .add("symbols-file", "s", StringArgument)

      for option in options do
        match option
        | ("initial-nbbo-file", let arg: String) =>
          initial_nbbo_file_path = arg
        | ("symbols-file", let arg: String) =>
          symbols_file_path = arg
        end
      end
      let symbol_data_partition = if symbols_file_path is None then
          Partition[Symboly val, String](
            SymbolPartitionFunction, LegalSymbols.symbols)
        else
          Partition[Symboly val, String](
            SymbolPartitionFunction,
            PartitionFileReader(symbols_file_path as String,
              env.root as AmbientAuth))
        end

      let init_file = InitFile(initial_nbbo_file_path, 46)

      let initial_report_msgs_trn: Array[Array[ByteSeq] val] trn =
        recover Array[Array[ByteSeq] val] end
      let connect_msg = HubProtocol.connect()
      let join_msg = HubProtocol.join("reports:market-spread")
      initial_report_msgs_trn.push(connect_msg)
      initial_report_msgs_trn.push(join_msg)
      let initial_report_msgs: Array[Array[ByteSeq] val] val =
        consume initial_report_msgs_trn

      let application = recover val
        Application("Market Spread App")
          .new_pipeline[FixOrderMessage val, Array[ByteSeq] val](
            "Orders", FixOrderFrameHandler)
            // .to[FixOrderMessage val](IdentityBuilder[FixOrderMessage val])
            .to_state_partition[Symboly val, String,
              (Array[ByteSeq] val | None), SymbolData](CheckOrder,
              SymbolDataBuilder, "symbol-data", symbol_data_partition
              where multi_worker = true)
            .to_sink(EmptyEncoder, recover [0] end,
              initial_report_msgs)
          .new_pipeline[FixNbboMessage val, None](
            "Nbbo", FixNbboFrameHandler
              where init_file = init_file)
            .to_state_partition[Symboly val, String, None,
               SymbolData](UpdateNbbo, SymbolDataBuilder, "symbol-data",
               symbol_data_partition where multi_worker = true)
            .done()
      end
      Startup(env, application, "market-spread")
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

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

class SymbolData is State
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
    ifdef debug then
      try
        Assert(sc_repo.contains("SymbolDataStateChange"),
        "Invariant violated: sc_repo.contains('SymbolDataStateChange')")
      else
        //TODO: how do we bail out here?
        None
      end
    end

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

class CheckOrder is StateComputation[FixOrderMessage val, Array[ByteSeq] val,
  SymbolData]
  fun name(): String => "Check Order against NBBO"

  fun apply(msg: FixOrderMessage val,
    sc_repo: StateChangeRepository[SymbolData],
    state: SymbolData): ((Array[ByteSeq] val | None), None)
  =>
    // @printf[I32]("!!CheckOrder\n".cstring())
    if state.should_reject_trades then
      let res = OrderResultEncoder(msg, state.last_bid, state.last_offer,
        Time.nanos())
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
    | let m: FixNbboMessage val => @printf[I32]("Got FixNbbo\n".cstring()); Fail(); error
    else
      @printf[I32]("Could not get FixOrder from incoming data\n".cstring())
      @printf[I32]("data size: %d\n".cstring(), data.size())
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
    | let m: FixOrderMessage val => @printf[I32]("Got FixOrder\n".cstring()); Fail(); error
    else
      @printf[I32]("Could not get FixNbbo from incoming data\n".cstring())
      @printf[I32]("data size: %d\n".cstring(), data.size())
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

primitive EmptyEncoder
  fun apply(a: Array[ByteSeq] val, wb: Writer = Writer): Array[ByteSeq] val =>
    a

primitive OrderResultEncoder
  fun apply(order: FixOrderMessage val, bid: F64, offer: F64, timestamp: U64):
    Array[ByteSeq] val
  =>
    ifdef "market_results" then
      @printf[I32](("!!" + order.order_id() + " " + order.symbol() + "\n").cstring())
    end
    //
    // msgs_size(4) | side(1) | account(4) | order_id(6) | symbol(4) |
    //   order_qty(8) | price(8) | bid(8) | offer(8) | timestamp(8)
    //

    var payload: Array[U8] iso = recover Array[U8](59) end

    // //Payload header (size == 59 bytes)
    // payload = Bytes.from_u32(59, consume payload)

    //Header (size == 55 bytes)
    let msgs_size: U32 = 1 + 4 + 6 + 4 + 8 + 8 + 8 + 8 + 8
    payload = Bytes.from_u32(msgs_size, consume payload)

    //Fields
    let side: U8 = match order.side()
    | Buy => SideTypes.buy()
    | Sell => SideTypes.sell()
    else
      Fail()
      0
    end
    payload.push(side)

    payload = Bytes.from_u32(order.account(), consume payload)

    ifdef debug then
      Invariant(order.order_id().array().size() == 6)
      Invariant(order.symbol().array().size() == 4)
    end

    // ASSUMPTION: 6 bytes
    for byte in order.order_id().array().values() do
      payload.push(byte)
    end
    // ASSUMPTION: 4 bytes
    for byte in order.symbol().array().values() do
      payload.push(byte)
    end

    payload = Bytes.from_f64(order.order_qty(), consume payload)
    payload = Bytes.from_f64(order.price(), consume payload)
    payload = Bytes.from_f64(bid, consume payload)
    payload = Bytes.from_f64(offer, consume payload)
    payload = Bytes.from_u64(timestamp, consume payload)

    HubProtocol.payload_into_array("rejected-orders",
      "reports:market-spread", consume payload)

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
