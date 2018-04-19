package application

import "wallarooapi/application/repr"

func MakePartition(partitionFunctionId uint64, partitionListId uint64) *Partition {
	return &Partition{partitionFunctionId, partitionListId}
}

type Partition struct {
	partitionFunctionId uint64
	partitionListId     uint64
}

func (p *Partition) Repr(idx uint64) *repr.Partition {
	return repr.MakePartition(p.partitionFunctionId, p.partitionListId, idx)
}
