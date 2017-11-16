package wallarooapi

import (
	"C"
	"fmt"
)

type PartitionFunction interface {
	Partition(data interface{}) uint64
}

//export PartitionFunctionU64Partition
func PartitionFunctionU64Partition(partitionFunctionId uint64, dataId uint64) uint64 {
	partitionFunction := GetComponent(partitionFunctionId).(PartitionFunction)
	data := GetComponent(dataId).(interface{})
	return partitionFunction.Partition(data)
}

//export PartitionListU64GetSize
func PartitionListU64GetSize(partitionListId uint64) uint64 {
	fmt.Printf("partitionListId = %d\n", partitionListId)
	partitionList := GetComponent(partitionListId).([]uint64)
	return uint64(len(partitionList))
}

//export PartitionListU64GetItem
func PartitionListU64GetItem(partitionListId uint64, idx uint64) uint64 {
	partitionList := GetComponent(partitionListId).([]uint64)
	return partitionList[idx]
}
