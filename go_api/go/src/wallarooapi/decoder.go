package wallarooapi

import (
	"C"
	"unsafe"
)

type FramedDecoder interface {
	HeaderLength() uint64
	PayloadLength(b []byte) uint64
	Decode(b []byte) interface{}
}

type Decoder interface {
	Decode(b []byte) interface{}
}

//export DecoderHeaderLength
func DecoderHeaderLength(decoderId uint64) uint64 {
	//decoder := GetComponent(decoderId, DecoderTypeId).(FramedDecoder)
	//return decoder.HeaderLength()

	return 4;
}

//export DecoderPayloadLength
func DecoderPayloadLength() uint64 {
//func DecoderPayloadLength(decoderId uint64, b unsafe.Pointer, size uint64) uint64 {
	//decoder := GetComponent(decoderId, DecoderTypeId).(FramedDecoder)
	//return decoder.PayloadLength(C.GoBytes(b, C.int(size)))

	return 42;
}

//export DecoderDecode
func DecoderDecode(decoderId uint64, b unsafe.Pointer, size uint64) uint64 {
	decoder := GetComponent(decoderId, DecoderTypeId).(Decoder)
	return AddComponent(decoder.Decode(C.GoBytes(b, C.int(size))), DataTypeId)
}
