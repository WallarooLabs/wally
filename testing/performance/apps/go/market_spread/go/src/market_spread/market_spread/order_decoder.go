package market_spread

import "encoding/binary"

type OrderDecoder struct{}

func (decoder *OrderDecoder) HeaderLength() uint64 {
	return 4
}

func (decoder *OrderDecoder) PayloadLength(b []byte) uint64 {
	return uint64(binary.BigEndian.Uint32(b[0:4]))
}

func (decoder *OrderDecoder) Decode(b []byte) interface{} {
	msgType := MessageType(b[0])
	if msgType != OrderType {
		panic("Wrong Fix message type, expected Order message. Did you connect the senders the wrong way around?")
	}
	return OrderFromByteSlice(b[1:])
}
