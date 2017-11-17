package wallarooapi

import (
	"C"
	"unsafe"
)

type Encoder interface {
	Encode(d interface{}) []byte
}

//export EncoderEncode
func EncoderEncode(encoderId uint64, dataId uint64, size *uint64) unsafe.Pointer {
	encoder := GetComponent(encoderId).(Encoder)
	data := GetComponent(dataId)
	res := encoder.Encode(data)
	*size = uint64(len(res))
	return C.CBytes(res)
}

type KafkaEncoder interface {
	Encode(d interface{}) ([]byte, []byte)
}

//export KafkaEncoderEncode
func KafkaEncoderEncode(encoderId uint64, dataId uint64, value *unsafe.Pointer, valueSize *uint64, key *unsafe.Pointer, keySize *uint64) {
	encoder := GetComponent(encoderId).(KafkaEncoder)
	data := GetComponent(dataId)
	valueRes, keyRes := encoder.Encode(data)
	*valueSize = uint64(len(valueRes))
	*keySize = uint64(len(keyRes))
	if *valueSize > 0 {
		*value = C.CBytes(valueRes)
	}
	if *keySize > 0 {
		*key = C.CBytes(keyRes)
	}
}
