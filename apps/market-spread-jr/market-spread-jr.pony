"""
This market-spread-jr partitions by symbol. In order to accomplish this,
given that partitioning happens inside the TCPConnection, we set up the
map from Symbol to State actor on startup using a hard coded list of symbols.
For many scenarios, this is a reasonable alternative. What would be ideal is
for classes like a TCPConnectionNotify to be able to receive messages as
callbacks. Something Sylvan and I are calling "async lambda". Its a cool idea.
Sylvan thinks it could be done but its not coming anytime soon, so...
Here we have this.

I tested this on my laptop. Important to note, I used giles sender and data
files from the "market-spread-perf-runs-08-19" which has a fix to correct
data handling for the fixish binary files. This will be merged to master
shortly but hasn't been yet.

I started trades/orders sender as:

/usr/bin/time -l ./sender -b 127.0.0.1:7001 -m 5000000 -s 300 -i 5_000_000 -f ../../demos/marketspread/1000trades-fixish.msg --ponythreads=1 -y -g 57

I started nbbo sender as:
/usr/bin/time -l ./sender -b 127.0.0.1:7000 -m 10000000 -s 300 -i 2_500_000 -f ../../demos/marketspread/1000nbbo-fixish.msg --ponythreads=1 -y -g 47

I started market-spread-jr as:
./market-spread-jr -i 127.0.0.1:7000 -j 127.0.0.1:7001 -o 127.0.0.1:7002 -e 10000000

With the above settings, based on the albeit, hacky perf tracking, I got:

145k/sec NBBO throughput
71k/sec Trades throughput

Memory usage for market-spread-jr was stable and came in around 22 megs. After
run was completed, I left market-spread-jr running and started up the senders
using the same parameters again and it performed equivalently to the first run
with no appreciable change in memory.

145k/sec NBBO throughput
71k/sec Trades throughput
22 Megs of memory used.

While I don't have the exact performance numbers for this version compared to
the previous version that was partitioning across 2 State actors based on last
letter of the symbol (not first due to so many having a leading "_" as
padding) this version performs much better.

I'm commiting this as is for posterity and then making a few changes.

N.B. as part of startup, we really should be setting initial values for each
symbol. This would be equiv to "end of day on last previous trading data".
"""
use "collections"
use "net"
use "buffered"
use "options"
use "time"
use "sendence/fix"
use "sendence/new-fix"

class NbboNotify is TCPConnectionNotify
  let _partitions: Map[String, State] val
  let _metrics: Metrics
  let _expected: USize
  var _header: Bool = true
  var _count: USize = 0

  new iso create(partitions: Map[String, State] val, metrics: Metrics, expected: USize) =>
    _partitions = partitions
    _metrics = metrics
    _expected = expected

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    if _header then
      try
        _count = _count + 1

        if _count == 1 then
          _metrics.set_start(Time.nanos())
        end
        if (_count % 500_000) == 0 then
          @printf[None]("Nbbo %zu\n".cstring(), _count)
        end
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

        conn.expect(expect)
        _header = false
      end
    else
      try
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()
        let  m = FixishMsgDecoder.nbbo(consume data)

        if _partitions.contains(m.symbol()) then
          try
            let s = _partitions(m.symbol())
            s.nbbo(m)
          end
        end
      else
        @printf[I32]("Error parsing Fixish\n".cstring())
      end

      conn.expect(4)
      _header = true


      if _count == _expected then
        _metrics.set_end(Time.nanos(), _expected)
      end
    end
    false

  fun ref accepted(conn: TCPConnection ref) =>
    @printf[None]("accepted\n".cstring())
    conn.expect(4)

  fun ref connected(sock: TCPConnection ref) =>
    @printf[None]("incoming connected\n".cstring())

class OrderNotify is TCPConnectionNotify
  let _partitions: Map[String, State] val
  let _metrics: Metrics
  let _expected: USize
  var _header: Bool = true
  var _count: USize = 0

  new iso create(partitions: Map[String, State] val, metrics: Metrics, expected: USize) =>
    _partitions = partitions
    _metrics = metrics
    _expected = expected

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    if _header then
      try
        _count = _count + 1
        if _count == 1 then
          _metrics.set_start(Time.nanos())
        end
        if (_count % 500_000) == 0 then
          @printf[None]("Order %zu\n".cstring(), _count)
        end
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

        conn.expect(expect)
        _header = false
      end
    else
      try
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()
        let  m = FixishMsgDecoder.order(consume data)
        if _partitions.contains(m.symbol()) then
          try
            let s = _partitions(m.symbol())
            s.order(m)
          end
        end
      else
        @printf[I32]("Error parsing Fixish\n".cstring())
      end

      conn.expect(4)
      _header = true

      if _count == _expected then
        _metrics.set_end(Time.nanos(), _expected)
      end
    end
    false

  fun ref accepted(conn: TCPConnection ref) =>
    @printf[None]("accepted\n".cstring())
    conn.expect(4)

  fun ref connected(sock: TCPConnection ref) =>
    @printf[None]("incoming connected\n".cstring())

class OutNotify is TCPConnectionNotify
  fun ref connected(sock: TCPConnection ref) =>
    @printf[None]("outgoing connected\n".cstring())

  fun ref throttled(sock: TCPConnection ref, x: Bool) =>
    if x then
      @printf[None]("outgoing throttled\n".cstring())
    else
      @printf[None]("outgoing no longerthrottled\n".cstring())
    end

actor State
  let _outgoing: TCPConnection
  let _metrics: Metrics
  let _expected: USize

  let _symbol: String
  var _value: (Bool, F64, F64) = (true, 0, 0)
  var _count: USize = 0
  var _order_count: USize = 0
  var _rejections: USize = 0

  new create(symbol: String, outgoing: TCPConnection, metrics: Metrics, expected: USize) =>
    _symbol = symbol
    _outgoing = outgoing
    _metrics = metrics
    _expected = expected

  be nbbo(msg: FixNbboMessage val) =>
    // assumes everything is nbbo at the moment
    let offer_bid_difference = msg.offer_px() - msg.bid_px()
    if (offer_bid_difference >= 0.05) or ((offer_bid_difference / msg.mid()) >= 0.05) then
      _value = (true, msg.bid_px(), msg.offer_px())
    else
      _value = (false, msg.bid_px(), msg.offer_px())
    end

    _count = _count + 1
    if ((_count % 25_000) == 0) and (_rejections > 0) then
      @printf[None]("%s rejections %zu\n".cstring(), _symbol.null_terminated().cstring(), _rejections)
    end

  be order(msg: FixOrderMessage val) =>
    if _value._1 == true then
      _rejections = _rejections + 1
    end

    _order_count = _order_count + 1

///
/// YAWN from here on down
///

actor Main
  let available_symbols: Array[String] =
  [
" PWR",
" AIG",
" LVS",
"AGEN",
"  GT",
"AMTD",
"PCAR",
" BBY",
" PRU",
"KORS",
"  FE",
"MDVN",
"AMBA",
"AMKR",
" BWA",
"FOLD",
"TROX",
"CRUS",
"  LC",
"NWSA",
" MCD",
"KERX",
"GALE",
" HBI",
"  MA",
" CVC",
"  PX",
" BRX",
" UNH",
" CBS",
" LNG",
" QEP",
"  CF",
"ENDP",
"PCRX",
" FMC",
"DISH",
"ADXS",
"EPZM",
"ASNA",
" FHN",
" CIE",
"  GS",
" UNP",
"GLOG",
" GCA",
" TSO",
"  LH",
" BMR",
" OXY",
" EMR",
" TAP",
"FAST",
" CAR",
"NTAP",
" STJ",
" PTX",
" AES",
" SYY",
" CPE",
" STI",
" CTL",
" RCL",
" CPN",
" DFS",
" GPS",
" JNS",
"EVHC",
" INO",
" SPW",
"ALNY",
" BEE",
"ALTR",
"  AR",
"  EW",
"PAYX",
"  CL",
" HCP",
" PEG",
"  PE",
"TTPH",
" DIS",
" AXP",
" BHI",
" MFA",
" MAT",
" ADM",
" NRZ",
"ESRX",
" UAL",
"NYMT",
" NFX",
"GOOG",
" PPL",
"MDCO",
" CYH",
" ODP",
" CRC",
" HFC",
" SYK",
"ALLY",
"SWKS",
" IBM",
" CNP",
"PLUG",
" XPO",
" ACN",
"TROW",
"NLNK",
"OREX",
"ALXN",
"STLD",
" EPE",
" FTI",
" BTU",
" DHR",
" APC",
"RPTP",
"IMGN",
" DHI",
"ZION",
"QRVO",
"LLTC",
"PTEN",
" CBI",
"SIAL",
"BIIB",
" CMO",
" HCN",
"GDDY",
" LYB",
" RRC",
"PRGO",
" SWC",
" KSS",
"AGNC",
"CALM",
"HOLX",
" CDE",
"TMUS",
" ESV",
"CMCS",
" GSM",
"WETF",
"SPLS",
" DVN",
" TSN",
" DDD",
"  MM",
" MNK",
"ACAD",
" BKD",
" PAH",
" BEN",
"  CI",
" PLD",
" VLO",
"INSM",
"LULU",
"  NI",
"DXCM",
" ACE",
"BCEI",
"ITCI",
" MON",
"WYNN",
" SNH",
" MPC",
"BURL",
" COG",
" CCL",
" SVU",
"ANTH",
" SLH",
" GGP",
" CLF",
"AVGO",
" HOT",
"  KN",
" HOG",
" FLR",
"MYGN",
"  UA",
" XON",
" ALL",
"DISC",
" BAH",
"ZINC",
" PGR",
"  DD",
" FLS",
"GERN",
"  BA",
" CRM",
" PSX",
" MOS",
"STWD",
"  EA",
"  HP",
" TWC",
"  HD",
" KND",
" NBL",
"JNPR",
" PAY",
"HCBK",
"AXTA",
"BMRN",
" CIM",
"MNKD",
"FEYE",
" SRC",
"INCY",
" GIS",
"DLTR",
" CVS",
"   M",
" WDC",
" LUK",
"BRCM",
"  PM",
" HRB",
"IDRA",
" JOY",
" CNC",
"BDSI",
" SKX",
"  SO",
"ACHN",
" GNW",
"JUNO",
"CTIC",
" JBL",
" NBR",
"EXAS",
"ARRY",
" TGT",
"BLUE",
"SCTY",
" ANF",
" ETN",
" YUM",
" COH",
"FCEL",
"ARWR",
" MUR",
" ABC",
" MTG",
"  SN",
"EXPE",
" SLM",
" SEE",
" AEP",
" HDS",
" HCA",
"   P",
" UTX",
"  WU",
" HON",
" AVP",
" DAL",
"  DG",
"BRK.",
" WBA",
" MCK",
"PETX",
"SGYP",
"ISIS",
" TWO",
"GNTX",
"SYMC",
" XEL",
"VRTX",
"PGRE",
" DDR",
"CIEN",
"SNDK",
"  DO",
"AMZN",
" TRN",
"HRTX",
" APA",
"  KR",
"  HK",
" CLR",
" WEN",
"CTSH",
" MPW",
" CFG",
"ARNA",
"SWFT",
"SNTA",
"  BK",
"GSAT",
" NWL",
" PEP",
" NUE",
" GLW",
" AET",
"ETFC",
" BBT",
"FITB",
" CNX",
" AMD",
" HIG",
"THRX",
"  CA",
" NOV",
" BAS",
"SLCA",
"PBCT",
"TSLA",
"PDLI",
"PPHM",
"CLDX",
" ATW",
"BBBY",
" MAR",
"  DE",
"NKTR",
"FINL",
"TSRO",
"GLNG",
" MET",
" CMI",
"ALKS",
"ILMN",
" FOX",
" IPG",
"XOMA",
" NEM",
" EOG",
" EIX",
" CCI",
" MMM",
"FNFG",
"NYCB",
"  FL",
" CAG",
"MRVL",
" VTR",
" LOW",
" MBI",
"MDRX",
" OLN",
" KBH"]

  new create(env: Env) =>
    var i_arg: (Array[String] | None) = None
    var j_arg: (Array[String] | None) = None
    var o_arg: (Array[String] | None) = None
    var expected: USize = 1_000_000

    try
      var options = Options(env)

      options
        .add("nbbo", "i", StringArgument)
        .add("order", "j", StringArgument)
        .add("out", "o", StringArgument)
        .add("expected", "e", I64Argument)

      for option in options do
        match option
        | ("nbbo", let arg: String) => i_arg = arg.split(":")
        | ("order", let arg: String) => j_arg = arg.split(":")
        | ("out", let arg: String) => o_arg = arg.split(":")
        | ("expected", let arg: I64) => expected = arg.usize()
        end
      end

      let i_addr = i_arg as Array[String]
      let j_addr = j_arg as Array[String]
      let out_addr = o_arg as Array[String]
      let metrics1 = Metrics("NBBO")
      let metrics2 = Metrics("Orders")

      let connect_auth = TCPConnectAuth(env.root as AmbientAuth)
      let out_socket = TCPConnection(connect_auth,
            OutNotify,
            out_addr(0),
            out_addr(1))

      let partitions: Map[String, State] trn = recover trn Map[String, State] end
      for i in available_symbols.values() do
        let s = State(i, out_socket, metrics1, expected)
        partitions(i) = s
      end

      let partitions_val: Map[String, State] val = consume partitions
      let listen_auth = TCPListenAuth(env.root as AmbientAuth)
      let nbbo = TCPListener(listen_auth,
            NbboListenerNotify(partitions_val, metrics1, expected),
            i_addr(0),
            i_addr(1))

      let order = TCPListener(listen_auth,
            OrderListenerNotify(partitions_val, metrics2, (expected/2)),
            j_addr(0),
            j_addr(1))

      @printf[I32]("Expecting %zu total messages\n".cstring(), expected)
    end

class NbboListenerNotify is TCPListenNotify
  let _partitions: Map[String, State] val
  let _metrics: Metrics
  let _expected: USize

  new iso create(partitions: Map[String, State] val, metrics: Metrics, expected: USize) =>
    _partitions = partitions
    _metrics = metrics
    _expected = expected

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    NbboNotify(_partitions, _metrics, _expected)

class OrderListenerNotify is TCPListenNotify
  let _partitions: Map[String, State] val
  let _metrics: Metrics
  let _expected: USize

  new iso create(partitions: Map[String, State] val, metrics: Metrics, expected: USize) =>
    _partitions = partitions
    _metrics = metrics
    _expected = expected

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    OrderNotify(_partitions, _metrics, _expected)

actor Metrics
  var start_t: U64 = 0
  var next_start_t: U64 = 0
  var end_t: U64 = 0
  var last_report: U64 = 0
  let _name: String
  new create(name: String) =>
    _name = name

  be set_start(s: U64) =>
    if start_t != 0 then
      next_start_t = s
    else
      start_t = s
    end
    @printf[I32]("Start: %zu\n".cstring(), start_t)

  be set_end(e: U64, expected: USize) =>
    end_t = e
    let overall = (end_t - start_t).f64() / 1_000_000_000
    let throughput = ((expected.f64() / overall) / 1_000).usize()
    @printf[I32]("%s End: %zu\n".cstring(), _name.cstring(), end_t)
    @printf[I32]("%s Overall: %f\n".cstring(), _name.cstring(), overall)
    @printf[I32]("%s Throughput: %zuk\n".cstring(), _name.cstring(), throughput)
    start_t = next_start_t
    next_start_t = 0
    end_t = 0

  be report(r: U64, s: U64, e: U64) =>
    last_report = (r + s + e) + last_report

primitive Bytes
  fun to_u32(a: U8, b: U8, c: U8, d: U8): U32 =>
    (a.u32() << 24) or (b.u32() << 16) or (c.u32() << 8) or d.u32()
