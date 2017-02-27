"""
Setting up a market-spread-cpp run (in order):
1) reports sink:
nc -l 127.0.0.1 5555 >> /dev/null

2) metrics sink:
nc -l 127.0.0.1 5001 >> /dev/null

3a) single worker
./market-spread-cpp -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:501 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n worker-name --ponythreads=4 --ponynoblock

3b) multi-worker
./market-spread-cpp -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n node-name --ponythreads=4 --ponynoblock -t -w 2

./market-spread-cpp -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n worker2 --ponythreads=4 --ponynoblock -w 2

4) orders:
giles/sender/sender -b 127.0.0.1:7000 -m 5000000 -s 300 -i 5_000_000 -f demos/marketspread/r3k-orders-fixish.msg -r --ponythreads=1 -y -g 57 -w

5) nbbo:
giles/sender/sender -b 127.0.0.1:7001 -m 10000000 -s 300 -i 2_500_000 -f demos/marketspread/r3k-nbbo-fixish.msg -r --ponythreads=1 -y -g 46 -w
"""

use "lib:wallaroo"
use "lib:market-spread-cpp"
use "lib:c++" if osx
use "lib:stdc++" if linux

use "collections"

use "sendence/hub"
use "wallaroo"
use "wallaroo/topology"
use "wallaroo/metrics"
use "wallaroo/tcp_source"
use "wallaroo/cpp_api/pony"
use "debug"
use "options"

use @get_order_source_decoder[Pointer[U8] val]()
use @get_nbbo_source_decoder[Pointer[U8] val]()
use @get_partition_function[Pointer[U8] val]()

use @get_check_order_no_update_no_output[Pointer[U8] val]()
use @get_update_nbbo_no_update_no_output[Pointer[U8] val]()

use @get_check_order_no_output[Pointer[U8] val]()
use @get_update_nbbo_no_output[Pointer[U8] val]()

use @get_check_order[Pointer[U8] val]()
use @get_update_nbbo[Pointer[U8] val]()

use @get_order_result_sink_encoder[Pointer[U8] val]()

use @get_symbol_data[Pointer[U8] val]()

primitive SourceDecoderTest
  fun app(init_file: InitFile val,
    symbol_data_partition: Partition[CPPData val, U64] val,
    initial_report_msgs: Array[Array[ByteSeq] val] val): Application val
  ? =>
    recover val
        Application("Market Spread Cpp")
          .new_pipeline[CPPData val, None]("order-decoder",
            recover CPPSourceDecoder(@get_order_source_decoder()) end)
            .to[CPPData val](FilterBuilder)
            .done()
          .new_pipeline[CPPData val, None]("nbbo-decoder",
            recover CPPSourceDecoder(@get_nbbo_source_decoder()) end)
            .to[CPPData val](FilterBuilder)
            .done()
      end

primitive ComputationsTest
  fun app(init_file: InitFile val,
    symbol_data_partition: Partition[CPPData val, U64] val,
    initial_report_msgs: Array[Array[ByteSeq] val] val): Application iso^
  ? =>
    recover
        Application("Market Spread App")
          .new_pipeline[CPPData val, CPPData val](
            "Orders", recover CPPSourceDecoder(@get_order_source_decoder()) end)
            .to_state_partition[CPPData val, U64,
              (CPPData val | None), CPPState](recover CPPStateComputation(@get_check_order_no_update_no_output()) end,
              SymbolDataBuilder, "symbol-data", symbol_data_partition
              where multi_worker = true)
            .done()
          .new_pipeline[CPPData val, None](
            "Nbbo", recover CPPSourceDecoder(@get_nbbo_source_decoder()) end
              where init_file = init_file)
            .to_state_partition[CPPData val, U64,
               (CPPData val | None), CPPState](recover CPPStateComputation(@get_update_nbbo_no_update_no_output()) end,
               SymbolDataBuilder, "symbol-data", symbol_data_partition
               where multi_worker = true)
            .done()
      end

primitive ComputationsAndStatesTest
  fun app(init_file: InitFile val,
    symbol_data_partition: Partition[CPPData val, U64] val,
    initial_report_msgs: Array[Array[ByteSeq] val] val): Application iso^
  ? =>
    recover
        Application("Market Spread App")
          .new_pipeline[CPPData val, CPPData val](
            "Orders", recover CPPSourceDecoder(@get_order_source_decoder()) end)
            .to_state_partition[CPPData val, U64,
              (CPPData val | None), CPPState](recover CPPStateComputation(@get_check_order_no_output()) end,
              SymbolDataBuilder, "symbol-data", symbol_data_partition
              where multi_worker = true)
            .done()
          .new_pipeline[CPPData val, None](
            "Nbbo", recover CPPSourceDecoder(@get_nbbo_source_decoder()) end
              where init_file = init_file)
            .to_state_partition[CPPData val, U64,
               (CPPData val | None), CPPState](recover CPPStateComputation(@get_update_nbbo_no_output()) end,
               SymbolDataBuilder, "symbol-data", symbol_data_partition
               where multi_worker = true)
            .done()
      end

primitive SinkEncoderTest
  fun app(init_file: InitFile val,
    symbol_data_partition: Partition[CPPData val, U64] val,
    initial_report_msgs: Array[Array[ByteSeq] val] val): Application iso^
  ? =>
    recover
        Application("Market Spread App")
          .new_pipeline[CPPData val, CPPData val](
            "Orders", recover CPPSourceDecoder(@get_order_source_decoder()) end)
            .to_state_partition[CPPData val, U64,
              (CPPData val | None), CPPState](recover CPPStateComputation(@get_check_order()) end,
              SymbolDataBuilder, "symbol-data", symbol_data_partition
              where multi_worker = true)
            .to_sink(recover CPPSinkEncoder(@get_order_result_sink_encoder()) end, recover [0] end,
              initial_report_msgs)
          .new_pipeline[CPPData val, None](
            "Nbbo", recover CPPSourceDecoder(@get_nbbo_source_decoder()) end
              where init_file = init_file)
            .to_state_partition[CPPData val, U64,
               (CPPData val | None), CPPState](recover CPPStateComputation(@get_update_nbbo()) end,
               SymbolDataBuilder, "symbol-data", symbol_data_partition
               where multi_worker = true)
            .done()
      end

type AllTest is SinkEncoderTest

type TestType is (SourceDecoderTest | ComputationsTest | ComputationsAndStatesTest | SinkEncoderTest | AllTest)

actor Main
  new create(env: Env) =>
    try
      var initial_nbbo_file_path =
        "../../demos/marketspread/initial-nbbo-fixish.msg"
      var symbols_file_path: (String | None) = None
      var test_level: TestType = AllTest
      let options = Options(env.args, false)

      options
        .add("initial-nbbo-file", "f", StringArgument)
        .add("symbols-file", "s", StringArgument)
        .add("source-decoder-test", "", None)
        .add("computations-test", "", None)
        .add("computations-and-states-test", "", None)
        .add("sink-encoder-test", "", None)

      for option in options do
        match option
        | ("initial-nbbo-file", let arg: String) =>
          initial_nbbo_file_path = arg
        | ("symbols-file", let arg: String) =>
          symbols_file_path = arg
        | ("source-decoder-test", None) =>
          test_level = SourceDecoderTest
        | ("computations-test", None) =>
          test_level = ComputationsTest
        | ("computations-and-states-test", None) =>
          test_level = ComputationsAndStatesTest
        | ("sink-encoder-test", None) =>
          test_level = SinkEncoderTest
        end
      end

      // For now don't use a file, always use the symbol data partition from code.
      //
      // let symbol_data_partition = if symbols_file_path is None then
      //     Partition[CPPData val, U64](
      //       SymbolPartitionFunction, LegalSymbols.symbols)
      //   else
      //     Partition[Symboly val, String](
      //       SymbolPartitionFunction,
      //       PartitionFileReader(symbols_file_path as String,
      //         env.root as AmbientAuth))
      //   end

      let symbol_data_partition =
        Partition[CPPData val, U64](
          recover CPPPartitionFunctionU64(recover @get_partition_function() end) end, LegalSymbols.symbols)


      let init_file = InitFile(initial_nbbo_file_path, 46)

      let initial_report_msgs_trn: Array[Array[ByteSeq] val] trn =
        recover Array[Array[ByteSeq] val] end
      let connect_msg = HubProtocol.connect()
      let join_msg = HubProtocol.join("reports:market-spread")
      initial_report_msgs_trn.push(connect_msg)
      initial_report_msgs_trn.push(join_msg)
      let initial_report_msgs: Array[Array[ByteSeq] val] val =
        consume initial_report_msgs_trn

      let application = test_level.app(consume init_file, consume symbol_data_partition, initial_report_msgs)
      Startup(env, application, None)
    else
      env.out.print("Could not build topology")
    end


primitive Filter
  fun name(): String => "filter"
  fun apply(r: CPPData val): None =>
    r.delete_obj()
    None

primitive FilterBuilder
  fun apply(): Computation[CPPData val, CPPData val] val =>
     Filter

class val SymbolDataBuilder
  fun apply(): CPPState => CPPState(@get_symbol_data())
  fun name(): String => "Market Data"

class LegalSymbols
  let symbols: Array[U64] val

  new create() =>
    let padded: Array[U64] trn = recover Array[U64] end
    for symbol in RawSymbols().values() do
      padded.push(RawSymbols.pad_symbol(symbol))
    end
    symbols = consume padded

primitive RawSymbols
  fun pad_symbol(s: String): U64 =>
    let padded_symbol = if s.size() == 4 then
      s
    else
      let diff = 4 - s.size()
      var padded = s
      for i in Range(0, diff) do
        padded = " " + padded
      end
      padded
    end

    var ret: U64 = 0

    for (i, c) in padded_symbol.array().pairs() do
      ret = ret + (c.u64() << (i.u64() * 8))
    end

    ret

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
