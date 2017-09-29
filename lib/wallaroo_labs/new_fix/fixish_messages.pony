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

use "buffered"
use "../fix"
use "../bytes"

primitive FixTypes
  fun order(): U8 => 1
  fun nbbo(): U8 => 2

primitive SideTypes
  fun buy(): U8 => 1
  fun sell(): U8 => 2

primitive FixishMsgEncoder
  fun order(side: Side val, account: U32, order_id': String, symbol': String,
    order_qty: F64, price: F64, transact_time': String,
    wb: Writer = Writer): Array[ByteSeq] val =>
      let order_id: String = _with_max_length(order_id', 6)
      let symbol: String = _with_max_length(symbol', 4)
      // TODO: truncating time is probably a bad idea as this will make time
      // unparseable. until we have a better solution for handling variable
      // message sizes, going with this for now. warn: you may end up with
      // unparseable times in some subset of messages with this.
      let transact_time: String = _with_max_length(transact_time', 21)

      //Header
      let msgs_size: USize = 1 + 1 + 4 + order_id.size()
        + symbol.size() + 8 + 8 + transact_time.size()
      wb.u32_be(msgs_size.u32())
      //Fields
      wb.u8(FixTypes.order())
      match side
      | Buy => wb.u8(SideTypes.buy())
      | Sell => wb.u8(SideTypes.sell())
      end
      wb.u32_be(account)
      wb.write(order_id.array())
      wb.write(symbol.array())
      wb.f64_be(order_qty)
      wb.f64_be(price)
      wb.write(transact_time.array())
      wb.done()

  fun nbbo(symbol': String, transact_time': String, bid_px: F64, offer_px: F64,
    wb: Writer = Writer): Array[ByteSeq] val =>
      let symbol: String = _with_max_length(symbol', 4)
      let transact_time: String = _with_max_length(transact_time', 21)

      //Header
      let msgs_size: USize = 1 + symbol.size() + transact_time.size() + 8 + 8
      wb.u32_be(msgs_size.u32())
      //Fields
      wb.u8(FixTypes.nbbo())
      wb.write(symbol)
      wb.write(transact_time)
      wb.f64_be(bid_px)
      wb.f64_be(offer_px)
      wb.done()

    fun _with_max_length(s: String, max: USize): String =>
      if s.size() <= max then
        s
      else
        s.trim(0, max)
      end


primitive FixishMsgDecoder
  fun apply(data: Array[U8] val): FixMessage val ? =>
    match data(0)?
    | FixTypes.order() => _order(data)?
    | FixTypes.nbbo() => _nbbo(data)
    else
      OtherFixMessage
    end

  fun _order(data: Array[U8] val): FixOrderMessage val ? =>
    // 0 -  1b - FixType (U8)
    // 1 -  1b - side (U8)
    // 2 -  4b - account (U32)
    // 6 -  6b - order id (String)
    //12 -  4b - symbol (String)
    //16 -  8b - order qty (F64)
    //24 -  8b - price (F64)
    //32 - 21b - transact_time (String)
    //     --
    //     53b (+ header -> 57b)

    let side = match data(1)?
    | SideTypes.buy() => Buy
    | SideTypes.sell() => Sell
    else
      error
    end
    let account = Bytes.to_u32(data(2)?, data(3)?, data(4)?, data(5)?)
    let order_id = _trim_string(data, 6, 6)
    let symbol = _trim_string(data, 12, 4)
    let order_qty: F64 = F64.from_bits(_u64_for(data, 16))
    let price: F64 = F64.from_bits(_u64_for(data, 24))
    let transact_time = _trim_string(data, 32, 21)
    FixOrderMessage(side, account, order_id, symbol, order_qty, price,
      transact_time)

  fun _nbbo(data: Array[U8] val): FixNbboMessage val =>
    // 0 -  1b - FixType (U8)
    // 1 -  4b - symbol (String)
    // 5 - 21b - transact_time (String)
    //26 -  8b - bid_px (F64)
    //34 -  8b - offer_px (F64)
    //      --
    //     42b (+ header -> 46b)
    var idx: USize = 1
    var cur_size: USize = 0

    let symbol = _trim_string(data, 1, 4)
    let transact_time = _trim_string(data, 5, 21)
    let bid_px: F64 = F64.from_bits(_u64_for(data, 26))
    let offer_px: F64 = F64.from_bits(_u64_for(data, 34))

    FixNbboMessage(symbol, transact_time, bid_px, offer_px)

  fun _size_for(data: Array[U8] val, idx: USize): USize ? =>
    Bytes.to_u32(data(idx)?, data(idx + 1)?, data(idx + 2)?,
      data(idx + 3)?).usize()

  fun _trim_string(data: Array[U8] val, idx: USize, size: USize): String =>
    String.from_array(data.trim(idx, idx + size))

  fun _u64_for(data: Array[U8] val, idx: USize): U64 =>
    try
      (data(idx)?.u64() << 56)
        or (data(idx + 1)?.u64() << 48)
        or (data(idx + 2)?.u64() << 40)
        or (data(idx + 3)?.u64() << 32)
        or (data(idx + 4)?.u64() << 24)
        or (data(idx + 5)?.u64() << 16)
        or (data(idx + 6)?.u64() << 8)
        or data(idx + 7)?.u64()
    else
      @printf[I32]("Problem decoding bits for 8 byte chunk.")
      0
    end
