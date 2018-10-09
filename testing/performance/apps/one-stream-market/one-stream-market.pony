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
One Stream Market App

Setting up a market spread run (in order):
1) reports sink (if not using Monitoring Hub):
sudo cset proc -s user -e numactl -- -C 14,17 chrt -f 80 ../../../../utils/data_receiver/data_receiver --framed --ponythreads=1 --ponypinasio --ponynoblock -w -l 0.0.0.0:5555 > received.txt

2) metrics sink (if not using Monitoring Hub):
sudo cset proc -s user -e numactl -- -C 14,17 chrt -f 80 ../../../../utils/data_receiver/data_receiver --framed --ponythreads=1 --ponypinasio --ponynoblock -w -l 0.0.0.0:5001 > received.txt

350 Symbols

3a) one stream market app (1 worker):
sudo cset proc -s user -e numactl -- -C 1-4,17 chrt -f 80 ./one-stream-market -i 127.0.0.1:7000 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n node-name -t --ponythreads=4 --ponynoblock

3b) one stream market app (multi-machine):
sudo cset proc -s user -e numactl -- -C 1-4,17 chrt -f 80 ./one-stream-market -i 0.0.0.0:7000 -o 127.0.0.1:5555 -m <MACHINE IP ADDRESS FOR METRICS>:5001 -c 0.0.0.0:12500 -d 0.0.0.0:12501 --ponythreads 4 --ponypinasio --ponynoblock -t -w 4

For each follower:
sudo cset proc -s user -e numactl -- -C 1-4,17 chrt -f 80 ./one-stream-market -i 0.0.0.0:7000 -o 127.0.0.1:5555 -m <METRICS>:5001 -c <INITIALIZER>:12500 --ponythreads 4 --ponypinasio --ponynoblock -n <NAME>

4) nbbo:
sudo cset proc -s user -e numactl -- -C 15,17 chrt -f 80 ../../../../giles/sender/sender -h 127.0.0.1:7000 -m 10000000000 -s 300 -i 2_500_000 -f ../../../data/market_spread/350-symbols_nbbo-fixish.msg -r --ponythreads=1 -y -g 46 --ponypinasio -w —ponynoblock
"""
use "assert"
use "buffered"
use "collections"
use "net"
use "serialise"
use "time"
use "wallaroo_labs/bytes"
use "wallaroo_labs/conversions"
use "wallaroo_labs/fix"
use "wallaroo_labs/hub"
use "wallaroo_labs/new_fix"
use "wallaroo_labs/options"
use "wallaroo_labs/time"
use "wallaroo"
use "wallaroo_labs/mort"
use "wallaroo/core/metrics"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/state"
use "wallaroo/core/topology"

actor Main
  new create(env: Env) =>
    try
      var initial_nbbo_file_path =
        "../../../data/market_spread/350-symbols_initial-nbbo-fixish.msg"
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
      let nbbo_data_partition = if symbols_file_path is None then
          Partitions[FixNbboMessage val](
            SymbolPartitionFunction, LegalSymbols.symbols)
        else
          Partitions[FixNbboMessage val](
            SymbolPartitionFunction,
            PartitionsFileReader(symbols_file_path as String,
              env.root as AmbientAuth))
        end

      let initial_report_msgs_trn = recover trn Array[Array[ByteSeq] val] end
      let connect_msg = HubProtocol.connect()
      let join_msg = HubProtocol.join("reports:market-spread")
      initial_report_msgs_trn.push(connect_msg)
      initial_report_msgs_trn.push(join_msg)
      let initial_report_msgs: Array[Array[ByteSeq] val] val =
        consume initial_report_msgs_trn

      let application = recover val
        Application("One Steam NBBO Updater App")
          .new_pipeline[FixNbboMessage val, NbboResult val](
            "Nbbo",
            TCPSourceConfig[FixNbboMessage val].from_options(FixNbboFrameHandler,
              TCPSourceConfigCLIParser(env.args)?(0)?))
            .to_state_partition[(NbboResult val | None), SymbolData](
              ProcessNbbo, SymbolDataBuilder, "symbol-data",
              nbbo_data_partition where multi_worker = true)
            .to_sink(TCPSinkConfig[NbboResult val].from_options(NbboResultEncoder,
              TCPSinkConfigCLIParser(env.args)?(0)?,
              initial_report_msgs))
      end
      Startup(env, application, "market-spread")
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

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
    out_writer.u8(BoolConverter.bool_to_u8(_should_reject_trades))

  fun ref read_log_entry(in_reader: Reader) ? =>
    _last_bid = in_reader.f64_be()?
    _last_offer = in_reader.f64_be()?
    _should_reject_trades = BoolConverter.u8_to_bool(in_reader.u8()?)

class SymbolDataStateChangeBuilder is StateChangeBuilder[SymbolData]
  fun apply(id: U64): StateChange[SymbolData] =>
    SymbolDataStateChange(id, "SymbolDataStateChange")

primitive ProcessNbbo is StateComputation[FixNbboMessage val, NbboResult val,
  SymbolData]
  fun name(): String => "Process NBBO"

  fun apply(msg: FixNbboMessage val,
    sc_repo: StateChangeRepository[SymbolData],
    state: SymbolData): ((NbboResult val | None), StateChange[SymbolData] ref)
  =>
    ifdef debug then
      try
        Assert(sc_repo.contains("SymbolDataStateChange"),
        "Invariant violated: sc_repo.contains('SymbolDataStateChange')")?
      else
        //TODO: how do we bail out here?
        None
      end
    end

    // @printf[I32]("!!Update NBBO\n".cstring())
    let state_change: SymbolDataStateChange ref =
      try
        sc_repo.lookup_by_name("SymbolDataStateChange")? as SymbolDataStateChange
      else
        //TODO: ideally, this should also register it. Not sure how though.
        SymbolDataStateChange(0, "SymbolDataStateChange")
      end
    let offer_bid_difference = msg.offer_px() - msg.bid_px()

    let should_reject_trades = (offer_bid_difference >= 0.05) or
      ((offer_bid_difference / msg.mid()) >= 0.05)

    state_change.update(should_reject_trades, msg.bid_px(), msg.offer_px())

    let res = NbboResult(msg, state.last_bid, state.last_offer, Time.nanos())
    (res, state_change)

  fun state_change_builders(): Array[StateChangeBuilder[SymbolData]] val =>
    recover val
      let scbs = Array[StateChangeBuilder[SymbolData]]
      scbs.push(recover val SymbolDataStateChangeBuilder end)
      scbs
    end

primitive FixNbboFrameHandler is FramedSourceHandler[FixNbboMessage val]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()

  fun decode(data: Array[U8] val): FixNbboMessage val ? =>
    match FixishMsgDecoder(data)?
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

class NbboResult
  let nbbo: FixNbboMessage val
  let bid: F64
  let offer: F64
  let timestamp: U64

  new val create(nbbo': FixNbboMessage val,
    bid': F64,
    offer': F64,
    timestamp': U64)
  =>
    nbbo = nbbo'
    bid = bid'
    offer = offer'
    timestamp = timestamp'

  fun string(): String =>
    (nbbo.symbol().clone().>append(", ")
      .>append(nbbo.bid_px().string()).>append(", ")
      .>append(nbbo.offer_px().string()).>append(", ")
      .>append(nbbo.mid().string()).>append(", ")
      .>append(bid.string()).>append(", ")
      .>append(offer.string()).>append(", ")
      .>append(timestamp.string())).clone()

primitive NbboResultEncoder
  fun apply(r: NbboResult val, wb: Writer = Writer): Array[ByteSeq] val =>
    ifdef "market_results" then
      @printf[I32](("!!" + r.nbbo.symbol() + r.nbbo.bid_px().string() + "\n").cstring())
    end
    //Header (size == 52 bytes)
    let msgs_size: USize = 4 + 8 + 8 + 8 + 8 + 8 + 8
    wb.u32_be(msgs_size.u32())
    //Fields
    wb.write(r.nbbo.symbol().array()) // assumption: 4 bytes
    wb.f64_be(r.nbbo.bid_px())
    wb.f64_be(r.nbbo.offer_px())
    wb.f64_be(r.bid)
    wb.f64_be(r.offer)
    wb.f64_be(r.nbbo.mid())
    wb.u64_be(r.timestamp)
    let payload = wb.done()
    HubProtocol.payload("nbbo-results", "reports:one-stream-market",
      consume payload, wb)
    wb.done()

class LegalSymbols
  let symbols: Array[String] val

  new create() =>
    let padded = recover trn Array[String] end
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
"AA"
"BAC"
"AAPL"
"FCX"
"SUNE"
"FB"
"RAD"
"INTC"
"GE"
"WMB"
"S"
"ATML"
"YHOO"
"F"
"T"
"MU"
"PFE"
"CSCO"
"MEG"
"HUN"
"GILD"
"MSFT"
"SIRI"
"SD"
"C"
"NRF"
"TWTR"
"ABT"
"VSTM"
"NLY"
"AMAT"
"X"
"NFLX"
"SDRL"
"CHK"
"KO"
"JCP"
"MRK"
"WFC"
"XOM"
"KMI"
"EBAY"
"MYL"
"ZNGA"
"FTR"
"MS"
"DOW"
"ATVI"
"ORCL"
"JPM"
"FOXA"
"HPQ"
"JBLU"
"RF"
"CELG"
"HST"
"QCOM"
"AKS"
"EXEL"
"ABBV"
"CY"
"VZ"
"GRPN"
"HAL"
"GPRO"
"CAT"
"OPK"
"AAL"
"JNJ"
"XRX"
"GM"
"MHR"
"DNR"
"PIR"
"MRO"
"NKE"
"MDLZ"
"V"
"HLT"
"TXN"
"SWN"
"AGN"
"EMC"
"CVX"
"BMY"
"SLB"
"SBUX"
"NVAX"
"ZIOP"
"NE"
"COP"
"EXC"
"OAS"
"VVUS"
"BSX"
"SE"
"NRG"
"MDT"
"WFM"
"ARIA"
"WFT"
"MO"
"PG"
"CSX"
"MGM"
"SCHW"
"NVDA"
"KEY"
"RAI"
"AMGN"
"HTZ"
"ZTS"
"USB"
"WLL"
"MAS"
"LLY"
"WPX"
"CNW"
"WMT"
"ASNA"
"LUV"
"GLW"
"BAX"
"HCA"
"NEM"
"HRTX"
"BEE"
"ETN"
"DD"
"XPO"
"HBAN"
"VLO"
"DIS"
"NRZ"
"NOV"
"MET"
"MNKD"
"MDP"
"DAL"
"XON"
"AEO"
"THC"
"AGNC"
"ESV"
"FITB"
"ESRX"
"BKD"
"GNW"
"KN"
"GIS"
"AIG"
"SYMC"
"OLN"
"NBR"
"CPN"
"TWO"
"SPLS"
"AMZN"
"UAL"
"MRVL"
"BTU"
"ODP"
"AMD"
"GLNG"
"APC"
"HL"
"PPL"
"HK"
"LNG"
"CVS"
"CYH"
"CCL"
"HD"
"AET"
"CVC"
"MNK"
"FOX"
"CRC"
"TSLA"
"UNH"
"VIAB"
"P"
"AMBA"
"SWFT"
"CNX"
"BWC"
"SRC"
"WETF"
"CNP"
"ENDP"
"JBL"
"YUM"
"MAT"
"PAH"
"FINL"
"BK"
"ARWR"
"SO"
"MTG"
"BIIB"
"CBS"
"ARNA"
"WYNN"
"TAP"
"CLR"
"LOW"
"NYMT"
"AXTA"
"BMRN"
"ILMN"
"MCD"
"NAVI"
"FNFG"
"AVP"
"ON"
"DVN"
"DHR"
"OREX"
"CFG"
"DHI"
"IBM"
"HCP"
"UA"
"KR"
"AES"
"STWD"
"BRCM"
"APA"
"STI"
"MDVN"
"EOG"
"QRVO"
"CBI"
"CL"
"ALLY"
"CALM"
"SN"
"FEYE"
"VRTX"
"KBH"
"ADXS"
"HCBK"
"OXY"
"TROX"
"NBL"
"MON"
"PM"
"MA"
"HDS"
"EMR"
"CLF"
"AVGO"
"INCY"
"M"
"PEP"
"WU"
"KERX"
"CRM"
"BCEI"
"PEG"
"NUE"
"UNP"
"SWKS"
"SPW"
"COG"
"BURL"
"MOS"
"CIM"
"CLNY"
"BBT"
"UTX"
"LVS"
"DE"
"ACN"
"DO"
"LYB"
"MPC"
"SNDK"
"AGEN"
"GGP"
"RRC"
"CNC"
"PLUG"
"JOY"
"HP"
"CA"
"LUK"
"AMTD"
"GERN"
"PSX"
"LULU"
"SYY"
"HON"
"PTEN"
"NWSA"
"MCK"
"SVU"
"DSW"
"MMM"
"CTL"
"BMR"
"PHM"
"CIE"
"BRCD"
"ATW"
"BBBY"
"BBY"
"HRB"
"ISIS"
"NWL"
"ADM"
"HOLX"
"MM"
"GS"
"AXP"
"BA"
"FAST"
"KND"
"NKTR"
"ACHN"
"REGN"
"WEN"
"CLDX"
"BHI"
"HFC"
"GNTX"
"GCA"
"CPE"
"ALL"
"ALTR"
"QEP"
"NSAM"
"ITCI"
"ALNY"
"SPF"
"INSM"
"PPHM"
"NYCB"
"NFX"
"TMO"
"TGT"
"GOOG"
"SIAL"
"GPS"
"MYGN"
"MDRX"
"TTPH"
"NI"
"IVR"
"SLH"]
end
