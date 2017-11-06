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

var serializedDict = SerializedDict {sync.RWMutex{}, make(map[uint64] []byte)}

var Serialize func(interface{}) []byte = func(c interface{}) []byte {
	return make([]byte, 0)
}

var Deserialize func([]byte) interface{} = func([]byte) interface{} {
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
func ComponentSerializeGetSpaceWrapper(componentId uint64) uint64 {
	buff := Serialize(GetComponent(componentId))
	payloadSize := len(buff)
	totalSize := payloadSize + 4
	finalBuff := make([]byte, totalSize)
	binary.BigEndian.PutUint32(finalBuff, uint32(payloadSize))
	copy(finalBuff[4:], buff)
	fmt.Println("FINAL BUFF")
	fmt.Println(finalBuff)
	fmt.Println(len(finalBuff))
	serializedDict.add(componentId, finalBuff)
	return uint64(len(finalBuff))
}

//export ComponentSerializeWrapper
func ComponentSerializeWrapper(componentId uint64, p unsafe.Pointer) {
	buff := serializedDict.get(componentId)
	b := C.CBytes(buff)
	C.memcpy(p, b, C.size_t(len(buff)))
	C.free(b)
	serializedDict.remove(componentId)
}

//export ComponentDeserializeWrapper
func ComponentDeserializeWrapper(buff unsafe.Pointer) uint64 {
	sizeBuff := C.GoBytes(buff, 4)
	payloadSize := binary.BigEndian.Uint32(sizeBuff)
	// turn the whole buffer into a byte slice, then skip first 4 bytes
	payloadBuff := C.GoBytes(buff, 4 + C.int(payloadSize))[4:]
	component := Deserialize(payloadBuff)
	return AddComponent(component)
}
