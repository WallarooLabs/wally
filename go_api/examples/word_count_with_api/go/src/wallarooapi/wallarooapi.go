package wallarooapi

import "C"

var componentDict = ComponentDict {make(map[uint64]interface{}), 1}

type ComponentDict struct {
	components map[uint64]interface{}
	nextId uint64
}

func (cd *ComponentDict) add(component interface{}) uint64 {
	cd.components[cd.nextId] = component
	lastId := cd.nextId
	cd.nextId++
	return lastId
}

func (cd *ComponentDict) get(id uint64) interface{} {
	return cd.components[id]
}

func (cd *ComponentDict) remove(id uint64) {
	delete(cd.components, id)
}

//export GetComponent
func GetComponent(id uint64) interface{} {
	return componentDict.get(id)
}

//export AddComponent
func AddComponent(component interface{}) uint64 {
	return componentDict.add(component)
}

//export RemoveComponent
func RemoveComponent(id uint64) {
	componentDict.remove(id)
}
