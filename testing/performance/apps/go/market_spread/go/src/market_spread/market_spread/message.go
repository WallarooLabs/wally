package market_spread

import (
	"encoding/binary"
	"math"
)

type SymbolMessage interface {
	GetSymbol() string
}

func float64FromByteSlice(buff []byte) float64 {
	bits := binary.BigEndian.Uint64(buff)
	float := math.Float64frombits(bits)
	return float
}

type Side int

const (
	BuySide  Side = 1
	SellSide Side = 2
)

type MessageType int

const (
	OrderType      MessageType = 1
	MarketDataType MessageType = 2
)

type Order struct {
	Side         Side
	Account      uint32
	OrderId      string
	Symbol       string
	Quantity     float64
	Price        float64
	TransactTime string
}

func NewOrder(side Side, account uint32, orderId string, symbol string, quantity float64, price float64, transactTime string) *Order {
	return &Order{side, account, orderId, symbol, quantity, price, transactTime}
}

func OrderFromByteSlice(buff []byte) *Order {
	side := Side(buff[0])
	account := binary.BigEndian.Uint32(buff[1:5])
	orderId := string(buff[5:11])
	symbol := string(buff[11:15])
	quantity := float64FromByteSlice(buff[15:23])
	price := float64FromByteSlice(buff[23:31])
	transactTime := string(buff[31:52])
	return NewOrder(side, account, orderId, symbol, quantity, price, transactTime)
}

func (o *Order) GetSymbol() string {
	return o.Symbol
}

type MarketData struct {
	Symbol       string
	TransactTime string // 21 bytes
	BidPrice     float64
	OfferPrice   float64
	Mid          float64
}

func NewMarketData(symbol string, transactTime string, bidPrice float64, offerPrice float64, mid float64) *MarketData {
	return &MarketData{symbol, transactTime, bidPrice, offerPrice, mid}
}

func MarketDataFromByteSlice(buff []byte) *MarketData {
	symbol := string(buff[0:4])
	transactTime := string(buff[4:25])
	bidPrice := float64FromByteSlice(buff[25:33])
	offerPrice := float64FromByteSlice(buff[33:41])
	mid := (bidPrice + offerPrice) / 2.0

	return NewMarketData(symbol, transactTime, bidPrice, offerPrice, mid)
}

func (md *MarketData) GetSymbol() string {
	return md.Symbol
}
