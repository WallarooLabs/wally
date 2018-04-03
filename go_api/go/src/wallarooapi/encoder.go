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
	encoder := GetComponent(encoderId, EncoderTypeId).(Encoder)
	data := GetComponent(dataId, DataTypeId)
	res := encoder.Encode(data)
	*size = uint64(len(res))
	return C.CBytes(res)
}

type KafkaEncoder interface {
	Encode(d interface{}) ([]byte, []byte, int32)
}

//export KafkaEncoderEncode
func KafkaEncoderEncode(encoderId uint64, dataId uint64, value *unsafe.Pointer, valueSize *uint64, key *unsafe.Pointer, keySize *uint64, partitionId *int32) {
	encoder := GetComponent(encoderId, EncoderTypeId).(KafkaEncoder)
	data := GetComponent(dataId, DataTypeId)
	valueRes, keyRes, partId := encoder.Encode(data)
        *partitionId = partId
	*valueSize = uint64(len(valueRes))
	*keySize = uint64(len(keyRes))
	if *valueSize > 0 {
		*value = C.CBytes(valueRes)
	}
	if *keySize > 0 {
		*key = C.CBytes(keyRes)
	}
}
