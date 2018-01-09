package wallarooapi

//#include <string.h>
//#include <stdlib.h>
import "C"

import (
	"encoding/binary"
	"fmt"
	"sync"
	"unsafe"
)

func makeSerializedDicts() []*SerializedDict {
	retSerializedDicts := make([]*SerializedDict, numComponentTypes)

	for i := uint64(0); i < numComponentTypes; i++ {
		retSerializedDicts[i] = NewSerializedDict()
	}

	return retSerializedDicts
}

var serializedDicts = makeSerializedDicts()

func NewSerializedDict() *SerializedDict {
	return &SerializedDict {sync.RWMutex{}, make(map[uint64] []byte)}
}

var Serialize func(interface{}) []byte = func(c interface{}) []byte {
	panic("You must supply a Serialize function")
	return make([]byte, 0)
}

var Deserialize func([]byte) interface{} = func([]byte) interface{} {
	panic("You must supply a Deserialize function")
	return nil
}

type SerializedDict struct {
	mu sync.RWMutex
	buffers map[uint64] []byte
}

func (sd *SerializedDict) add(id uint64, buffer []byte) {
	sd.mu.Lock()
	defer sd.mu.Unlock()
	sd.buffers[id] = buffer
}

func (sd *SerializedDict) get(id uint64) []byte {
	sd.mu.RLock()
	defer sd.mu.RUnlock()
	return sd.buffers[id]
}

func (sd *SerializedDict) remove(id uint64) {
	sd.mu.Lock()
	defer sd.mu.Unlock()
	delete(sd.buffers, id)
}

//export ComponentSerializeGetSpaceWrapper
func ComponentSerializeGetSpaceWrapper(componentId uint64, componentTypeId uint64) uint64 {
	component := GetComponent(componentId, componentTypeId)
	if component == nil {
		panic(componentId)
	}
	buff := Serialize(component)
	if (buff == nil) || (len(buff) == 0) {
		panic(componentId)
	}
	payloadSize := len(buff)
	totalSize := payloadSize + 4
	finalBuff := make([]byte, totalSize)
	binary.BigEndian.PutUint32(finalBuff, uint32(payloadSize))
	copy(finalBuff[4:], buff)
	serializedDicts[componentTypeId].add(componentId, finalBuff)
	return uint64(len(finalBuff))
}

//export ComponentSerializeWrapper
func ComponentSerializeWrapper(componentId uint64, p unsafe.Pointer, componentType uint64) {
	buff := serializedDicts[componentType].get(componentId)
	if (buff == nil) || (len(buff) == 0) {
		panic(fmt.Sprintf("panic on componentId %d, componentType %d", componentId, componentType))
	}
	b := C.CBytes(buff)
	C.memcpy(p, b, C.size_t(len(buff)))
	C.free(b)
}

//export ComponentDeserializeWrapper
func ComponentDeserializeWrapper(buff unsafe.Pointer, componentTypeId uint64) uint64 {
	sizeBuff := C.GoBytes(buff, 4)
	payloadSize := binary.BigEndian.Uint32(sizeBuff)
	// turn the whole buffer into a byte slice, then skip first 4 bytes
	payloadBuff := C.GoBytes(buff, 4 + C.int(payloadSize))[4:]
	component := Deserialize(payloadBuff)
	return AddComponent(component, componentTypeId)
}

func RemoveSerialized(id uint64, componentType uint64) {
	serializedDicts[componentType].remove(id)
}
