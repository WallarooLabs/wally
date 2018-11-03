package wallarooapi

import (
	"C"
	"sync"
)

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
	shard := m.GetShard(key)
	shard.Lock()
	shard.items[key] = value
	shard.Unlock()
}

func (m ConcurrentMap) Load(key uint64) (interface{}, bool) {
	shard := m.GetShard(key)
	shard.RLock()
	val, ok := shard.items[key]
	shard.RUnlock()
	return val, ok
}

func (m ConcurrentMap) Delete(key uint64) {
	shard := m.GetShard(key)
	shard.Lock()
	delete(shard.items, key)
	shard.Unlock()
}
