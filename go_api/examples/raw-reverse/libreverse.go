package main

import (
	"C"
	"encoding/binary"
	"unicode/utf8"
	"unsafe"
)

var (
	pointers = PointerMap {make(map[uint64](interface {})), 1}
)

type PointerMap struct {
	pointers map[uint64](interface {})
	nextItem uint64
}

func (this *PointerMap) add(o interface {}) uint64 {
	this.pointers[this.nextItem] = o
	currentItem := this.nextItem
	this.nextItem++
	return currentItem
}

func (this PointerMap) lookup(token uint64) (interface {}) {
	return this.pointers[token]
}

//export CallComputationFunc
func CallComputationFunc(computationToken uint64, dataToken uint64) uint64 {
	computation := pointers.lookup(computationToken).(func(interface {})(interface {}))
	data := pointers.lookup(dataToken)
	return (&pointers).add(computation(data))
}

//export CallDecodeFunc
func CallDecodeFunc(decoderToken uint64, dataP unsafe.Pointer, l uint64) uint64 {
	decoder := pointers.lookup(decoderToken).(func([]byte)(interface {}))
	data := C.GoBytes(dataP, C.int(l))
	return (&pointers).add(decoder(data))
}

//export CallEncodeFunc
func CallEncodeFunc(encoderToken uint64, dataToken uint64, size *uint64) unsafe.Pointer {
	encoder := pointers.lookup(encoderToken).(func(interface {})([]byte))
	data := pointers.lookup(dataToken)
	b := encoder(data)
	*size = uint64(len(b))
	return C.CBytes(b)
}

//export GetComputationFunc
func GetComputationFunc() uint64 {
	return (&pointers).add(reverseFunc)
}

//export GetDecodeFunc
func GetDecodeFunc() uint64 {
	return (&pointers).add(decodeFunc)
}

//export GetEncodeFunc
func GetEncodeFunc() uint64 {
	return (&pointers).add(encodeFunc)
}

func reverseFunc(data interface {}) interface {} {
	s := data.(string)
	return reverse(s)
}

func reverse(s string) string {
	o := make([]rune, utf8.RuneCountInString(s))
	i := len(o)
	for _, c := range s {
		i--
		o[i] = c
	}
	return string(o)
}

func decodeFunc (data []byte) interface {} {
	return string(data[:])
}

func encodeFunc(data interface {}) []byte {
	s := data.(string)
	buff := make([]byte, 4 + len(s))
	binary.BigEndian.PutUint32(buff, uint32(len(s)))
	copy(buff[4:], s)
	return buff
}

func main() {
}
