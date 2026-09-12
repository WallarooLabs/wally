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
Provides utilities for generating and formatting FIX messages and market data.
"""

use "random"
use "time"
use "collections"
use "wallaroo_labs/fix"

"""
Stores instrument name, ticker, and price information.
"""
class InstrumentData
  let _name: String val
  let _ticker: String val
  let _price: F64

  """
  Creates instrument data with the given name, ticker, and price.
  """
  new val create(name': String, ticker': String, price': F64) =>
    _name = name'
    _ticker = ticker'
    _price = price'

  """
  Returns the instrument name.
  """
  fun name(): String val => _name

  """
  Returns the instrument ticker symbol.
  """
  fun ticker(): String val => _ticker

  """
  Returns the instrument price.
  """
  fun price(): F64 => _price

"""
Parses instrument data from a comma-separated string.
"""
primitive InstrumentParser
  """
  Parses a string into instrument data.
  Returns None when the input cannot be parsed.
  """
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

"""
Generates random numbers and alphanumeric strings.
"""
class RandomNumberGenerator
  let _rand: Random
  let _alphanumerics: Array[String] =
    ["0"; "1"; "2"; "3"; "4"; "5"; "6"; "7"; "8"; "9"
    "A";"B";"C";"D";"E";"F";"G";"H";"I";"J";"K";"L";"M";"N";"O";"P";"Q"; "R"
    "S";"T";"U";"V";"W";"X";"Y";"Z";"a";"b";"c";"d";"e";"f";"g";"h"; "i";"j"
    "k";"l";"m";"n";"o";"p";"q";"r";"s";"t";"u";"v";"w";"x";"y";"z"]

  """
  Creates a random number generator with the given seed.
  """
  new create(seed: U64 = Time.nanos()) =>
    _rand = MT(seed)

  """
  Returns a random real number.
  """
  fun ref apply(): F64 =>
    _rand.real()

  """
  Returns the underlying random number generator.
  """
  fun ref random(): Random =>
    _rand

  """
  Returns a random integer less than the given value.
  """
  fun ref rand_int(n: U64): U64 =>
    _rand.int(n)

  """
  Generates a random alphanumeric string of the given length.
  """
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

"""
Generates random FIX NBBO messages for an instrument.
"""
primitive RandomFixNbboGenerator
  """
  Creates a FIX NBBO message using generated bid and offer prices.
  """
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
      let inc_base = number_generator.rand_int((max_inc * 100).u64()).f64()
      var inc_val: F64 = inc_base / 100
      offer = bid + inc_val
    end

    FixNbboMessage(symbol, timestamp, bid, offer)

"""
Generates random FIX order messages for an instrument.
"""
primitive RandomFixOrderGenerator
  """
  Creates a FIX order message with randomly generated order details.
  """
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

"""
Formats FIX order, NBBO, and heartbeat messages as strings.
"""
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

  """
  Formats a FIX order message as a string.
  """
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

  """
  Formats a FIX NBBO message as a string.
  """
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

  """
  Formats a FIX heartbeat message with the given timestamp.
  """
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
