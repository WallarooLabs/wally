import wallaroo
import struct
import time

FIXTYPE_ORDER = 1
FIXTYPE_MARKET_DATA = 2

SIDETYPE_BUY = 1
SIDETYPE_SELL = 2

def test_python():
    return "hello python"

def str_to_partition(stringable):
    ret = 0
    for x in range(0, len(stringable)):
        ret += ord(stringable[x]) << (x * 8)

    return ret

def application_setup(args):
    symbol_partitions = [str_to_partition(x.rjust(4)) for x in valid_symbols()]

    ab = wallaroo.ApplicationBuilder("market-spread")
    ab.new_pipeline(
            "Orders", OrderDecoder()
        ).to_state_partition_u64(
            CheckOrder(), SymbolDataBuilder(), "symbol-data",
            SymbolPartitionFunction(), symbol_partitions
       ).to_sink(
            OrderResultEncoder()
       ).new_pipeline(
            "Market Data", MarketDataDecoder()
        ).to_state_partition_u64(
            UpdateMarketData(), SymbolDataBuilder(), "symbol-data",
            SymbolPartitionFunction(), symbol_partitions
        ).done()
    return ab.build()

class SymbolData(object):
    def __init__(self, last_bid, last_offer, should_reject_trades):
        self.last_bid = last_bid
        self.last_offer = last_offer
        self.should_reject_trades = should_reject_trades

class SymbolDataBuilder(object):
    def build(self):
        return SymbolData(0.0, 0.0, True)

class SymbolPartitionFunction(object):
    def partition(self, data):
        return str_to_partition(data.symbol)

class CheckOrder(object):
    def name(self):
        return "Check Order"

    def compute(self, data, state):
        if state.should_reject_trades:
            print "rejecting"
            ts = int(time.time() * 100000)
            return OrderResult(data, state.last_bid,
                state.last_offer, ts)
        return None

class Order(object):
    def __init__(self, side, account, order_id, symbol, qty , price,
            transact_time):
        self.side = side
        self.account = account
        self.order_id = order_id
        self.symbol = symbol
        self.qty  = qty
        self.price = price
        self.transact_time = transact_time

class OrderDecoder(object):
    def header_length(self):
        return 4

    def payload_length(self, bs):
        return struct.unpack(">I", bs)[0]

    def decode(self, bs):
        """
        0 -  1b - FixType (U8)
        1 -  1b - side (U8)
        2 -  4b - account (U32)
        6 -  6b - order id (String)
        12 -  4b - symbol (String)
        16 -  8b - order qty (F64)
        24 -  8b - price (F64)
        32 - 21b - transact_time (String)
        """
        order_type = struct.unpack(">B", bs[0:1])[0]
        if order_type != FIXTYPE_ORDER:
            raise "Wrong Fix message type. Did you connect the senders the wrong way around?"
        side = struct.unpack(">B", bs[1:2])[0]
        account = struct.unpack(">I", bs[2:6])[0]
        order_id = struct.unpack("6s", bs[6:12])[0]
        symbol = struct.unpack("4s", bs[12:16])[0]
        qty = struct.unpack(">d", bs[16:24])[0]
        price = struct.unpack(">d", bs[24:32])[0]
        transact_time = struct.unpack("21s", bs[32:53])[0]

        return Order(side, account, order_id, symbol, qty, price, transact_time)

class OrderResult(object):
     def __init__(self, order, last_bid, last_offer, timestamp):
        self.order = order
        self.bid = last_bid
        self.offer = last_offer
        self.timestamp = timestamp

class OrderResultEncoder(object):
    def encode(self, data):
        # data is a string
        msg_size = 1 + 4 + 6 + 4 + 8 + 8 + 8 + 8 + 8
        p = struct.pack(">IHI6s4sddddQ",
            msg_size,
            data.order.side,
            data.order.account,
            data.order.order_id,
            data.order.symbol,
            data.order.qty,
            data.order.price,
            data.bid,
            data.offer,
            data.timestamp)

        return bytearray(p)

class MarketDataMessage(object):
    def __init__(self, symbol, transact_time, bid, offer):
        self.symbol = symbol
        self.transact_time = transact_time
        self.bid = bid
        self.offer = offer
        self.mid = (bid + offer) / 2.0

class MarketDataDecoder(object):
    def header_length(self):
        return 4

    def payload_length(self, bs):
        return struct.unpack(">I", bs)[0]

    def decode(self, bs):
        """
        0 -  1b - FixType (U8)
        1 -  4b - symbol (String)
        5 -  21b - transact_time (String)
        26 - 8b - bid_px (F64)
        34 - 8b - offer_px (F64)
        """
        order_type = struct.unpack(">B", bs[0:1])[0]
        if order_type != FIXTYPE_MARKET_DATA:
            raise "Wrong Fix message type. Did you connect the senders the wrong way around?"
        symbol = struct.unpack(">4s", bs[1:5])[0]
        transact_time = struct.unpack(">21s", bs[5:26])[0]
        bid = struct.unpack(">d", bs[26:34])[0]
        offer = struct.unpack(">d", bs[34:42])[0]

        return MarketDataMessage(symbol, transact_time, bid, offer)

class UpdateMarketData(object):
    def name(self):
        return "Update Market Data"

    def compute(self, data, state):
        offer_bid_difference = data.offer - data.bid

        should_reject_trades = (offer_bid_difference >= 0.05) or ((offer_bid_difference / data.mid) >= 0.05)

        state.last_bid = data.bid
        state.last_offer = data.offer
        state.should_reject_trades = should_reject_trades

        if should_reject_trades:
            print "Should reject trades"

        return None

def valid_symbols():
    return [
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
"SLH"
    ]
