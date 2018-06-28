package wallarooapi

import (
	"C"
	"unsafe"
)

type PartitionFunction interface {
	Partition(data interface{}) []byte
}

//export PartitionFunctionPartition
func PartitionFunctionPartition(partitionFunctionId uint64, dataId uint64, sz *uint64) unsafe.Pointer {
	partitionFunction := GetComponent(partitionFunctionId, PartitionFunctionTypeId).(PartitionFunction)
	data := GetComponent(dataId, DataTypeId).(interface{})
	b := partitionFunction.Partition(data)
	sz = len(b)
	return C.CBytes(b)
}

//export PartitionListGetSize
func PartitionListGetSize(partitionListId uint64) uint64 {
	partitionList := GetComponent(partitionListId, PartitionListTypeId).([][]byte)
	return uint64(len(partitionList))
}

//export PartitionListGetItem
func PartitionListGetItem(partitionListId uint64, idx uint64, sz *uint64) unsafe.Pointer {
	partitionList := GetComponent(partitionListId, PartitionListTypeId).([][]byte)
	b := partitionList[idx]
	sz = len(b)
	return C.CBytes(b)
}
