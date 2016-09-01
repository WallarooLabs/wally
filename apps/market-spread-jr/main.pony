use "collections"
use "net"
use "options"
use "time"
use "metrics"
use "sendence/hub"

class OutNotify is TCPConnectionNotify
  let _name: String

  new iso create(name: String) =>
    _name = name

  fun ref connected(sock: TCPConnection ref) =>
    @printf[None]("%s outgoing connected\n".cstring(),
      _name.null_terminated().cstring())

  fun ref throttled(sock: TCPConnection ref, x: Bool) =>
    if x then
      @printf[None]("%s outgoing throttled\n".cstring(),
        _name.null_terminated().cstring())
    else
      @printf[None]("%s outgoing no longer throttled\n".cstring(),
        _name.null_terminated().cstring())
    end

actor Main
  new create(env: Env) =>
    var i_arg: (Array[String] | None) = None
    var j_arg: (Array[String] | None) = None
    var m_arg: (Array[String] | None) = None
    var o_arg: (Array[String] | None) = None
    var expected: USize = 1_000_000

    try
      var options = Options(env.args)

      options
        .add("expected", "e", I64Argument)
        .add("metrics", "m", StringArgument)
        .add("nbbo", "i", StringArgument)
        .add("order", "j", StringArgument)
        .add("out", "o", StringArgument)

      for option in options do
        match option
        | ("expected", let arg: I64) => expected = arg.usize()
        | ("metrics", let arg: String) => m_arg = arg.split(":")
        | ("nbbo", let arg: String) => i_arg = arg.split(":")
        | ("order", let arg: String) => j_arg = arg.split(":")
        | ("out", let arg: String) => o_arg = arg.split(":")
        end
      end

      let i_addr = i_arg as Array[String]
      let j_addr = j_arg as Array[String]
      let m_addr = m_arg as Array[String]
      let o_addr = o_arg as Array[String]
      let metrics1 = JrMetrics("NBBO")
      let metrics2 = JrMetrics("Orders")

      let connect_auth = TCPConnectAuth(env.root as AmbientAuth)
      let metrics_socket = TCPConnection(connect_auth,
            OutNotify("metrics"),
            m_addr(0),
            m_addr(1))
      let connect_msg = HubProtocol.connect()
      let metrics_join_msg = HubProtocol.join("metrics:market-spread")
      metrics_socket.writev(connect_msg)
      metrics_socket.writev(metrics_join_msg)

      let reports_socket = TCPConnection(connect_auth,
            OutNotify("rejections"),
            o_addr(0),
            o_addr(1))
      let reports_join_msg = HubProtocol.join("reports:market-spread")
      reports_socket.writev(connect_msg)
      reports_socket.writev(reports_join_msg)

      let symbol_actors: Map[String, StateRunner[SymbolData]] trn = recover trn Map[String, StateRunner[SymbolData]] end
      for i in legal_symbols().values() do
        let s = StateRunner[SymbolData](
          lambda(): SymbolData => SymbolData end, metrics_socket, 
            "market-spread")
        symbol_actors(i) = s
      end

      let symbol_to_actor: Map[String, StateRunner[SymbolData]] val = 
        consume symbol_actors

      let nbbo_source = NBBOSource(SymbolRouter(symbol_to_actor))

      let listen_auth = TCPListenAuth(env.root as AmbientAuth)
      let nbbo = TCPListener(listen_auth,
            SourceListenerNotify(nbbo_source, metrics1, expected),
            i_addr(0),
            i_addr(1))

      let check_order = CheckOrder(reports_socket)
      let order_source = OrderSource(SymbolRouter(symbol_to_actor),
        check_order)

      let order = TCPListener(listen_auth,
            SourceListenerNotify(order_source, metrics2, (expected/2)),
            j_addr(0),
            j_addr(1))

      @printf[I32]("Expecting %zu total messages\n".cstring(), expected)
    end

  fun legal_symbols(): Array[String] =>
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
