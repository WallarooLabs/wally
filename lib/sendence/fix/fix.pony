use "collections"

// FixParser._parse should be own primitive that we
// test just for getting correct parsing of fix

primitive  FixParser
  fun apply(i: String): (FixMessage val | None) =>
    try
      let raw = _parse(i)
      if (raw("35") == "S") then
        _nbbo(raw)
      elseif (raw("35") == "D") then
        _order(raw)
      else
        OtherFixMessage
      end
    else
      None
    end

  fun _parse(i: String): Map[String, String] ? =>
    let out: Map[String, String] = Map[String, String]
    let split = i.split("\x01")
      split.pop()
    for part in (consume split).values() do
//      @printf[I32]("part: %s\n".cstring(), part.cstring())
      let tuple = part.split("=")
      out(tuple(0)) = tuple(1)
    end
    out

  fun _nbbo(i: Map[String, String]): FixNbboMessage val  ? =>
    FixNbboMessage(
      i("55")
      , i("60")
      , i("132").f64()
      , i("133").f64()
      )

  fun _order(i: Map[String, String]): FixOrderMessage val ? =>
    let side = match i("54")
      | "1" => Buy
      | "2" => Sell
    else
      error
    end

    FixOrderMessage(
      side
      , i("1")
      , i("11")
      , i("55")
      , i("38").f64()
      , i("44").f64()
      , i("60")
      )

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

  fun string(fmt: FormatSettings = FormatSettingsDefault): String iso^ =>
    "FixNbboMessage".string(fmt)

class FixOrderMessage is (Equatable[FixOrderMessage] & Stringable)
  let _side: Side
  let _account: String
  let _order_id: String
  let _symbol: String
  let _order_qty: F64
  let _price: F64
  let _transact_time: String

  new val create(
    side': Side
    , account': String
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

  fun side(): Side => _side
  fun account(): String => _account
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

  fun string(fmt: FormatSettings = FormatSettingsDefault): String iso^ =>
    "FixOrderMessage".string(fmt)


primitive OtherFixMessage

type Side is (Buy | Sell)

primitive Buy
primitive Sell

