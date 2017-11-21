package wallarooapi

//static char *getCommandlineArg(char **args, int idx) {
//  return args[idx];
//}
//
import "C"

import(
	"sync"
)

var Args []string = make([]string, 0)

//export WallarooApiSetArgs
func WallarooApiSetArgs(argv **C.char, argc C.int) {
	for i := 0; i <= int(argc); i++ {
		Args = append(Args, C.GoString(C.getCommandlineArg(argv, C.int(i))))
	}
}

var componentDict = ComponentDict {sync.RWMutex{}, make(map[uint64]interface{}), 1}

type ComponentDict struct {
	mu sync.RWMutex
	components map[uint64]interface{}
	nextId uint64
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
	RemoveSerialized(id)
}
