package market_spread

import (
	"encoding/binary"
	"math"
)

func byteSliceFromFloat64(f float64) []byte {
	buff := make([]byte, 8)
	bits := math.Float64bits(f)
	binary.BigEndian.PutUint64(buff, bits)
	return buff
}

type OrderResultEncoder struct{}

func (ore *OrderResultEncoder) Encode(data interface{}) []byte {
	messageSize := 56
	output := make([]byte, messageSize)
	orderResult := data.(*OrderResult)
	order := orderResult.Order
	binary.BigEndian.PutUint16(output[0:2], uint16(order.Side))
	binary.BigEndian.PutUint32(output[2:6], order.Account)
	copy(output[6:12], []byte(order.OrderId))
	copy(output[12:16], []byte(order.Symbol))
	copy(output[16:24], byteSliceFromFloat64(order.Quantity))
	copy(output[24:32], byteSliceFromFloat64(order.Price))
	copy(output[32:40], byteSliceFromFloat64(orderResult.Bid))
	copy(output[40:48], byteSliceFromFloat64(orderResult.Offer))
	binary.BigEndian.PutUint64(output[48:56], orderResult.Timestamp)

	messageSizeOut := make([]byte, 4)
	binary.BigEndian.PutUint32(messageSizeOut, uint32(messageSize))
	output = append(messageSizeOut, output...)
	return output
}
