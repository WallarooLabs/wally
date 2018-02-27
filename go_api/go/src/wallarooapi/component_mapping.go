package wallarooapi

import (
	"C"
	"sync"
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
	//components sync.Map
	components ConcurrentMap
}

func NewComponentDict() *ComponentDict {
	return &ComponentDict{0, NewConcurrentMap()}
	//return &ComponentDict{id: 0}
}

func (cd *ComponentDict) add(component interface{}) uint64 {
	var id = atomic.AddUint64(&cd.id, 1)
	//var id = cd.id + 1
	cd.components.Store(id, component)
	//cd.id = id
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
	//RemoveSerialized(id, componentType)
}

// MAP

var SHARD_COUNT = uint64(16384)

type ConcurrentMap []*ConcurrentMapShared

type ConcurrentMapShared struct {
	items map[uint64]interface{}
	sync.RWMutex
}

func NewConcurrentMap() ConcurrentMap {
	m := make(ConcurrentMap, SHARD_COUNT)
	for i := uint64(0); i < SHARD_COUNT; i++ {
		m[i] = &ConcurrentMapShared{items: make(map[uint64]interface{})}
	}
	return m
}

func (m ConcurrentMap) GetShard(key uint64) *ConcurrentMapShared {
	return m[key%SHARD_COUNT]
}

func (m ConcurrentMap) Store(key uint64, value interface{}) {
	// Get map shard.
	shard := m.GetShard(key)
	shard.Lock()
	shard.items[key] = value
	shard.Unlock()
}

func (m ConcurrentMap) Load(key uint64) (interface{}, bool) {
	// Get shard
	shard := m.GetShard(key)
	//shard.RLock()
	// Get item from shard.
	val, ok := shard.items[key]
	//shard.RUnlock()
	return val, ok
}

func (m ConcurrentMap) Delete(key uint64) {
	// Try to get shard.
	shard := m.GetShard(key)
	shard.Lock()
	delete(shard.items, key)
	shard.Unlock()
}
