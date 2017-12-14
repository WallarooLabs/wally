package wallarooapi

import (
	"C"
	"sync"
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
	mu sync.RWMutex
	components map[uint64]interface{}
	nextId uint64
}

func NewComponentDict() *ComponentDict {
	return &ComponentDict {sync.RWMutex{}, make(map[uint64]interface{}), 1}
}

func (cd *ComponentDict) add(component interface{}) uint64 {
	cd.mu.Lock()
	defer cd.mu.Unlock()
	cd.components[cd.nextId] = component
	lastId := cd.nextId
	cd.nextId++
	return lastId
}

func (cd *ComponentDict) get(id uint64) interface{} {
	cd.mu.RLock()
	defer cd.mu.RUnlock()
	return cd.components[id]
}

func (cd *ComponentDict) remove(id uint64) {
	cd.mu.Lock()
	defer cd.mu.Unlock()
	delete(cd.components, id)
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
