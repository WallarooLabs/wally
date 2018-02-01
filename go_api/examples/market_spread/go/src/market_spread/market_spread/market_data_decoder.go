package market_spread

//import (
//	"encoding/binary"
//)

type MarketDataDecoder struct {}

func (decoder *MarketDataDecoder) HeaderLength() uint64 {
	return 4
}

func (decoder *MarketDataDecoder) PayloadLength(b []byte) uint64 {
	return uint64(binary.BigEndian.Uint32(b[0:4]))
}

func (decoder *MarketDataDecoder) Decode(b []byte) interface{} {
	msgType := MessageType(b[0])
	if msgType != MarketDataType {
		panic("Wrong Fix message type, expected Market Data message. Did you connect the senders the wrong way around?")
	}
	return MarketDataFromByteSlice(b[1:])
}
