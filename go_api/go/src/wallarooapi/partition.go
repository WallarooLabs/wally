package wallarooapi

import (
	"C"
	"fmt"
)

type PartitionFunction interface {
	Partition(data interface{}) string
}

//export PartitionFunctionPartition
func PartitionFunctionPartition(partitionFunctionId uint64, dataId uint64) *C.char {
	partitionFunction := GetComponent(partitionFunctionId, PartitionFunctionTypeId).(PartitionFunction)
	data := GetComponent(dataId, DataTypeId).(interface{})
	s := partitionFunction.Partition(data)
	return C.CString(s)
}

//export PartitionListGetSize
func PartitionListGetSize(partitionListId uint64) uint64 {
	fmt.Printf("partitionListId = %d\n", partitionListId)
	partitionList := GetComponent(partitionListId, PartitionListTypeId).([]string)
	return uint64(len(partitionList))
}

//export PartitionListGetItem
func PartitionListGetItem(partitionListId uint64, idx uint64) *C.char {
	partitionList := GetComponent(partitionListId, PartitionListTypeId).([]string)
	s := partitionList[idx]
	return C.CString(s)
}
