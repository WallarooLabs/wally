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
	decoder := GetComponent(decoderId).(FramedDecoder)
	return decoder.HeaderLength()
}

//export DecoderPayloadLength
func DecoderPayloadLength(decoderId uint64, b unsafe.Pointer, size uint64) uint64 {
	decoder := GetComponent(decoderId).(FramedDecoder)
	return decoder.PayloadLength(C.GoBytes(b, C.int(size)))
}

//export DecoderDecode
func DecoderDecode(decoderId uint64, b unsafe.Pointer, size uint64) uint64 {
	decoder := GetComponent(decoderId).(Decoder)
	return AddComponent(decoder.Decode(C.GoBytes(b, C.int(size))))
}
