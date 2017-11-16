package wallarooapi

import "C"

type StateComputation interface {
	Name() string
	Compute(data interface{}, state interface{}) (interface {}, bool)
}

//export StateComputationName
func StateComputationName(computationId uint64) *C.char {
	computation := GetComponent(computationId).(StateComputation)
	return C.CString(computation.Name())
}

//export StateComputationCompute
func StateComputationCompute(computationId uint64, dataId uint64, stateId uint64, stateChanged *uint64) uint64 {
	computation := GetComponent(computationId).(StateComputation)
	data := GetComponent(dataId).(interface{})
	state := GetComponent(stateId).(interface{})
	res, sc := computation.Compute(data, state)
	if sc {
		*stateChanged = 1
	} else {
		*stateChanged = 0
	}
	if res == nil {
		return 0
	}
	return AddComponent(res)
}

type StateComputationMulti interface {
	Name() string
	Compute(data interface{}, state interface{}) ([]interface {}, bool)
}

//export StateComputationMultiName
func StateComputationMultiName(computationId uint64) *C.char {
	computation := GetComponent(computationId).(StateComputationMulti)
	return C.CString(computation.Name())
}

//export StateComputationMultiCompute
func StateComputationMultiCompute(computationId uint64, dataId uint64, stateId uint64, stateChanged *uint64, size *uint64) uint64 {
	computation := GetComponent(computationId).(StateComputationMulti)
	data := GetComponent(dataId).(interface{})
	state := GetComponent(stateId).(interface{})
	res, sc := computation.Compute(data, state)
	if sc {
		*stateChanged = 1
	} else {
		*stateChanged = 0
	}
	if res == nil {
		return 0
	}

	*size = uint64(len(res))
	resHolder := make([]uint64, len(res))

	for i, r := range res {
		resHolder[i] = AddComponent(r)
	}

	return AddComponent(resHolder)
}

type StateBuilder interface {
	Name() string
	Build() interface {}
}

//export StateBuilderName
func StateBuilderName(stateBuilderId uint64) *C.char {
	stateBuilder := GetComponent(stateBuilderId).(StateBuilder)
	return C.CString(stateBuilder.Name())
}

//export StateBuilderBuild
func StateBuilderBuild(stateBuilderId uint64) uint64 {
	stateBuilder := GetComponent(stateBuilderId).(StateBuilder)
	state := stateBuilder.Build()
	return AddComponent(state)
}
