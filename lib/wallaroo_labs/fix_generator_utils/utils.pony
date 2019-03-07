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

use "random"
use "time"
use "collections"
use "wallaroo_labs/fix"

class InstrumentData
  let _name: String val
  let _ticker: String val
  let _price: F64

  new val create(name': String, ticker': String, price': F64) =>
    _name = name'
    _ticker = ticker'
    _price = price'

  fun name(): String val => _name
  fun ticker(): String val => _ticker
  fun price(): F64 val => _price

primitive InstrumentParser
  fun apply(i: String): (InstrumentData val | None) =>
    try
      let split = i.split(",")
      let name = split(1)?
      let ticker = split(3)?
      let price = split(2)?.f64()?
      InstrumentData(name, ticker, price)
    else
      None
    end

class RandomNumberGenerator
  let _rand: Random
  let _alphanumerics: Array[String] =
    ["0"; "1"; "2"; "3"; "4"; "5"; "6"; "7"; "8"; "9"
    "A";"B";"C";"D";"E";"F";"G";"H";"I";"J";"K";"L";"M";"N";"O";"P";"Q"; "R"
    "S";"T";"U";"V";"W";"X";"Y";"Z";"a";"b";"c";"d";"e";"f";"g";"h"; "i";"j"
    "k";"l";"m";"n";"o";"p";"q";"r";"s";"t";"u";"v";"w";"x";"y";"z"]

  new create(seed: U64 = Time.nanos()) =>
    _rand = MT(seed)

  fun ref apply(): F64 =>
    _rand.real()

  fun ref random(): Random =>
    _rand

  fun ref rand_int(n: U64): U64 =>
    _rand.int(n)

  fun ref rand_alphanumeric(length: U64): String =>
    var string = "".clone()
    let alphanumerics_length = _alphanumerics.size().u64()
    for i in Range[U64](0, length) do
      var selected_char = "0"
      try
        selected_char = _alphanumerics(rand_int(alphanumerics_length).usize())?
      end
      string = (string.clone()
        .>append(selected_char))
        .clone()
    end
    string

primitive RandomFixNbboGenerator
  fun apply(instrument: InstrumentData val,
    number_generator: RandomNumberGenerator,
    is_rejected: Bool,
    timestamp: String): FixNbboMessage val
  =>
    let price: F64 = instrument.price()
    let symbol: String = instrument.ticker()
    var bid: F64
    var offer: F64
    if is_rejected then
      var new_price: F64 = instrument.price() + number_generator()
      bid = new_price - (((0.05 + number_generator()) * 0.1) + 0.01)
      offer = bid + (number_generator() * 0.03) + 0.05
    else
      bid = price + number_generator()
      var max_inc: F64 = 0.05 - 0.01
      var inc_val: F64 = (number_generator.rand_int((max_inc * 100).u64())
      / 100).f64()
      offer = bid + inc_val
    end

    FixNbboMessage(symbol, timestamp, bid, offer)

primitive RandomFixOrderGenerator
  fun apply(instrument: InstrumentData val,
    dice: Dice,
    number_generator: RandomNumberGenerator,
    timestamp: String): FixOrderMessage val
  =>
    let order_qty: F64 = (dice(1,65) * 10).f64()
    let client_id: U32 = dice(1,300).u32()
    let price = instrument.price()
    let symbol = instrument.ticker()
    let side_num = dice(1,2)
    let side =
      match side_num
      | 1 => Buy
      | 2 => Sell
      else
        Buy
      end

    let order_id = number_generator.rand_alphanumeric(6)

    FixOrderMessage(side, client_id, order_id, symbol,
      order_qty, price, timestamp)

class FixMessageStringify
  let _quote: String = """""""
  let _delimiter: String = "\x01"
  let _fix_version: String = "8=FIX.4.2"
  let _order_header: String = "35=D"
  let _symbol_header: String = "55="
  let _timestamp_header: String = "60="
  let _side_header: String = "54="
  let _acct_header: String = "1="
  let _order_id_header: String = "11="
  let _qty_header: String = "38="
  let _price_header: String = "44="
  let _nbbo_header: String = "35=S"
  let _bid_header: String = "132="
  let _offer_header: String = "133="
  let _heartbeat_header: String = "35=0"
  let _new_line: String = "\n"
  let _client_prefix: String = "CLIENT"

  fun order(fix_order_message: FixOrderMessage val): String =>
    let side_num =
      match fix_order_message.side()
      | Buy => "1"
      | Sell => "2"
      else
        "2"
      end
    (_quote.clone()
      .>append(_fix_version)
      .>append(_delimiter)
      .>append(_order_header)
      .>append(_delimiter)
      .>append(_symbol_header)
      .>append(fix_order_message.symbol())
      .>append(_delimiter)
      .>append(_timestamp_header)
      .>append(fix_order_message.transact_time())
      .>append(_delimiter)
      .>append(_side_header)
      .>append(side_num)
      .>append(_delimiter)
      .>append(_acct_header)
      .>append(_client_prefix)
      .>append(fix_order_message.account().string())
      .>append(_delimiter)
      .>append(_order_id_header)
      .>append(fix_order_message.order_id())
      .>append(_delimiter)
      .>append(_price_header)
      .>append(fix_order_message.price().string())
      .>append(_delimiter)
      .>append(_qty_header)
      .>append(fix_order_message.order_qty().string())
      .>append(_delimiter)
      .>append(_quote)
      .>append(_new_line)
      ).clone()

  fun nbbo(fix_nbbo_message: FixNbboMessage val): String =>
    (_quote.clone()
      .>append(_fix_version)
      .>append(_delimiter)
      .>append(_nbbo_header)
      .>append(_delimiter)
      .>append(_symbol_header)
      .>append(fix_nbbo_message.symbol())
      .>append(_delimiter)
      .>append(_timestamp_header)
      .>append(fix_nbbo_message.transact_time())
      .>append(_delimiter)
      .>append(_bid_header)
      .>append(fix_nbbo_message.bid_px().string())
      .>append(_delimiter)
      .>append(_offer_header)
      .>append(fix_nbbo_message.offer_px().string())
      .>append(_delimiter)
      .>append(_quote)
      .>append(_new_line)
    ).clone()

  fun heartbeat(timestamp: String): String =>
    (_quote.clone()
      .>append(_fix_version)
      .>append(_delimiter)
      .>append(_heartbeat_header)
      .>append(_delimiter)
      .>append(_timestamp_header)
      .>append(timestamp)
      .>append(_delimiter)
      .>append(_quote)
      .>append(_new_line)
    ).clone()
