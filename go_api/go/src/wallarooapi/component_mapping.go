package wallarooapi

import (
	"C"
	"sync/atomic"
)

const (
	DataTypeId uint64 = 0
	ComputationTypeId uint64 = 1
	ComputationBuilderTypeId uint64 = 2
	StateComputationTypeId uint64 = 3
	PartitionFunctionTypeId uint64 = 4
	PartitionListTypeId uint64 = 5
	EncoderTypeId = 6
	DecoderTypeId = 7
	StateTypeId = 8
	StateBuilderTypeId = 9
	LastTypeId = 10
)

const numComponentTypes uint64 = LastTypeId

func makeComponentDicts() []*ComponentDict {
	retComponentDicts := make([]*ComponentDict, numComponentTypes)

	for i := uint64(0); i < numComponentTypes; i++ {
		retComponentDicts[i] = NewComponentDict()
	}

	return retComponentDicts
}

var componentDicts = makeComponentDicts()

type ComponentDict struct {
	id uint64
	components ConcurrentMap
}

func NewComponentDict() *ComponentDict {
	return &ComponentDict{0, NewConcurrentMap()}
}

func (cd *ComponentDict) add(component interface{}) uint64 {
	var id = atomic.AddUint64(&cd.id, 1)
	cd.components.Store(id, component)
	return id
}

func (cd *ComponentDict) get(id uint64) interface{} {
	result, _ := cd.components.Load(id)
	return result
}

func (cd *ComponentDict) remove(id uint64) {
	cd.components.Delete(id)
}

//export GetComponent
func GetComponent(id uint64, componentType uint64) interface{} {
	return componentDicts[componentType].get(id)
}

//export AddComponent
func AddComponent(component interface{}, componentType uint64) uint64 {
	return componentDicts[componentType].add(component)
}

//export RemoveComponent
func RemoveComponent(id uint64, componentType uint64) {
	componentDicts[componentType].remove(id)
	RemoveSerialized(id, componentType)
}
