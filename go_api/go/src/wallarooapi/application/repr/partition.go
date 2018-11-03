package repr

func MakePartition(partitionFunctionId uint64, partitionListId uint64, partitionId uint64) *Partition {
	return &Partition{"PartitionU64", partitionFunctionId, partitionListId, partitionId}
}

type Partition struct {
	Class               string
	PartitionFunctionId uint64
	PartitionListId     uint64
	PartitionId         uint64
}
