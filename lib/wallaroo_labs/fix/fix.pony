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

use "collections"

// FixParser._parse should be own primitive that we
// test just for getting correct parsing of fix

primitive  FixParser
  fun apply(i: String): (FixMessage val | None) =>
    try
      let raw = _parse(i)?
      if (raw("35")? == "S") then
        _nbbo(raw)?
      elseif (raw("35")? == "D") then
        _order(raw)?
      else
        OtherFixMessage
      end
    else
      None
    end

  fun _parse(i: String): Map[String, String] ? =>
    let out: Map[String, String] = Map[String, String]
    let split = i.split("\x01")
      split.pop()?
    for part in (consume split).values() do
      let tuple = part.split("=")
      out(tuple(0)?) = tuple(1)?
    end
    out

  fun _nbbo(i: Map[String, String]): FixNbboMessage val  ? =>
    let padded_symbol = pad_symbol(i("55")?)
    let symbol = _with_max_length(padded_symbol, 4)
    FixNbboMessage(
      symbol
      , i("60")?
      , i("132")?.f64()?
      , i("133")?.f64()?
      )

  fun _order(i: Map[String, String]): FixOrderMessage val ? =>
    let side = match i("54")?
      | "1" => Buy
      | "2" => Sell
    else
      error
    end

    let account = i("1")?.substring(6).u32()?

    let padded_symbol = pad_symbol(i("55")?)
    let symbol = _with_max_length(padded_symbol, 4)

    FixOrderMessage(
      side
      , account
      , i("11")?
      , symbol
      , i("38")?.f64()?
      , i("44")?.f64()?
      , i("60")?
      )

  fun pad_symbol(symbol': String): String =>
    var symbol = symbol'
    var symbol_diff =
      if symbol.size() < 4 then
        4 - symbol.size()
      else
        0
      end
    for i in Range(0, symbol_diff) do
      symbol = " " + symbol
    end
    symbol

  fun _with_max_length(s: String, max: USize): String =>
    if s.size() <= max then
      s
    else
      s.trim(0, max)
    end

type FixMessage is (FixNbboMessage | FixOrderMessage | OtherFixMessage)

class FixNbboMessage is (Equatable[FixNbboMessage] & Stringable)
  let _symbol: String
  let _transact_time: String
  let _bid_px: F64
  let _offer_px: F64
  let _mid: F64

  new val create(
    symbol': String
    , transact_time': String
    , bid_px': F64
    , offer_px': F64
    )
  =>
    _symbol = symbol'
    _transact_time = transact_time'
    _bid_px = bid_px'
    _offer_px = offer_px'
    _mid = (_bid_px + _offer_px) / 2.0

  fun symbol(): String => _symbol
  fun transact_time(): String => _transact_time
  fun bid_px(): F64 => _bid_px
  fun offer_px(): F64 => _offer_px
  fun mid(): F64 => _mid

  fun eq(o: box->FixNbboMessage): Bool =>
    (_symbol == o._symbol)
    and (_transact_time == o._transact_time)
    and (_bid_px == o._bid_px)
    and (_offer_px == o._offer_px)
    and (_mid == o._mid)

  fun string(): String iso^ =>
    (_symbol.clone()
      .>append(_transact_time)
      .>append(_bid_px.string())
      .>append(_offer_px.string())
      .>append(_mid.string())).clone()

class FixOrderMessage is (Equatable[FixOrderMessage] & Stringable)
  let _side: Side val
  let _account: U32
  let _order_id: String
  let _symbol: String
  let _order_qty: F64
  let _price: F64
  let _transact_time: String

  new val create(
    side': Side val
    , account': U32
    , order_id': String
    , symbol': String
    , order_qty': F64
    , price': F64
    , transact_time': String
    )
  =>
    _side = side'
    _account = account'
    _order_id = order_id'
    _symbol = symbol'
    _order_qty = order_qty'
    _price = price'
    _transact_time = transact_time'

  fun side(): Side val => _side
  fun account(): U32 => _account
  fun order_id(): String => _order_id
  fun symbol(): String => _symbol
  fun order_qty(): F64 => _order_qty
  fun price(): F64 => _price
  fun transact_time(): String => _transact_time

  fun eq(o: box->FixOrderMessage): Bool =>
    (_side is o._side)
    and (_account == o._account)
    and (_order_id == o._order_id)
    and (_symbol == o._symbol)
    and (_order_qty == o._order_qty)
    and (_price == o._price)
    and (_transact_time == o._transact_time)

  fun string(): String iso^ =>
    (_side.string().clone().>append(", ")
      .>append(_account.string()).>append(", ")
      .>append(_order_id).>append(", ")
      .>append(_symbol).>append(", ")
      .>append(_order_qty.string()).>append(", ")
      .>append(_price.string()).>append(", ")
      .>append(_transact_time)).clone()

primitive OtherFixMessage

trait Side
  fun string(): String

primitive Buy is Side
  fun string(): String => "buy"
primitive Sell is Side
  fun string(): String => "sell"

