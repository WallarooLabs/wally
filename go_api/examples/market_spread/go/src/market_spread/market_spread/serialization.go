package market_spread

import (
	"bytes"
	"encoding/binary"
	"encoding/gob"
	"fmt"
	"reflect"
)

type componentType uint32

const (
	symbolPartitionFunctionType componentType = iota
	orderDecoderType
	marketDataDecoderType
	checkOrderType
	updateMarketDataType
	orderType
	marketDataType
	orderResultType
	symbolDataType
	symbolDataBuilderType
	orderResultEncoderType
)

func typeBytes(ct componentType) []byte {
	buff := make([]byte, 4)
	binary.BigEndian.PutUint32(buff, uint32(ct))
	return buff
}

func Serialize(c interface{}) []byte {
	buffer := bytes.NewBuffer(make([]byte, 0))
	enc := gob.NewEncoder(buffer)

	switch t := c.(type) {
	case *SymbolPartitionFunction:
		enc.Encode(symbolPartitionFunctionType)
	case *OrderDecoder:
		enc.Encode(orderDecoderType)
	case *MarketDataDecoder:
		enc.Encode(marketDataDecoderType)
	case *CheckOrder:
		enc.Encode(checkOrderType)
	case *UpdateMarketData:
		enc.Encode(updateMarketDataType)
	case *Order:
		enc.Encode(orderType)
		enc.Encode(c)
	case *MarketData:
		enc.Encode(marketDataType)
		enc.Encode(c)
	case *OrderResult:
		enc.Encode(orderResultType)
		enc.Encode(c)
	case *SymbolData:
		enc.Encode(symbolDataType)
		enc.Encode(c)
	case *SymbolDataBuilder:
		enc.Encode(symbolDataBuilderType)
	case *OrderResultEncoder:
		enc.Encode(orderResultEncoderType)
	default:
		panic(fmt.Sprintf("SERIALIZE MISSED A CASE: %s", reflect.TypeOf(t)))
	}

	return buffer.Bytes()
}

func Deserialize(buff []byte) interface{} {
	var obj interface{} = nil

	b := bytes.NewBuffer(buff)
	dec := gob.NewDecoder(b)

	var t componentType
	dec.Decode(&t)

	switch t {
	case symbolPartitionFunctionType:
		obj = &SymbolPartitionFunction{}
	case orderDecoderType:
		obj = &OrderDecoder{}
	case marketDataDecoderType:
		obj = &MarketDataDecoder{}
	case checkOrderType:
		obj = &CheckOrder{}
	case updateMarketDataType:
		obj = &UpdateMarketData{}
	case orderType:
		obj = &Order{}
		dec.Decode(obj)
	case marketDataType:
		obj = &MarketData{}
		dec.Decode(obj)
	case orderResultType:
		obj = &OrderResult{}
		dec.Decode(obj)
	case symbolDataType:
		obj = &SymbolData{}
		dec.Decode(obj)
	case symbolDataBuilderType:
		obj = &SymbolDataBuilder{}
	case orderResultEncoderType:
		obj = &OrderResultEncoder{}
	default:
		panic(fmt.Sprintf("DESERIALIZE MISSED A CASE: %d", t))
	}

	return obj
}
