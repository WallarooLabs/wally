package wallarooapi

import "C"

type StateComputation interface {
	Name() string
	Compute(data interface{}, state interface{}) (interface {}, bool)
}

//export StateComputationName
func StateComputationName(computationId uint64) *C.char {
	computation := GetComponent(computationId, StateComputationTypeId).(StateComputation)
	return C.CString(computation.Name())
}

//export StateComputationCompute
func StateComputationCompute(computationId uint64, dataId uint64, stateId uint64, stateChanged *uint64) uint64 {
	computation := GetComponent(computationId, StateComputationTypeId).(StateComputation)
	data := GetComponent(dataId, DataTypeId).(interface{})
	state := GetComponent(stateId, StateTypeId).(interface{})
	res, sc := computation.Compute(data, state)
	if sc {
		*stateChanged = 1
	} else {
		*stateChanged = 0
	}
	if res == nil {
		return 0
	}
	return AddComponent(res, DataTypeId)
}

type StateComputationMulti interface {
	Name() string
	Compute(data interface{}, state interface{}) ([]interface {}, bool)
}

//export StateComputationMultiName
func StateComputationMultiName(computationId uint64) *C.char {
	computation := GetComponent(computationId, StateComputationTypeId).(StateComputationMulti)
	return C.CString(computation.Name())
}

//export StateComputationMultiCompute
func StateComputationMultiCompute(computationId uint64, dataId uint64, stateId uint64, stateChanged *uint64, size *uint64) uint64 {
	computation := GetComponent(computationId, StateComputationTypeId).(StateComputationMulti)
	data := GetComponent(dataId, DataTypeId).(interface{})
	state := GetComponent(stateId, StateTypeId).(interface{})
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
		resHolder[i] = AddComponent(r, DataTypeId)
	}

	return AddComponent(resHolder, DataTypeId)
}

type StateBuilder interface {
	Name() string
	Build() interface {}
}

//export StateBuilderName
func StateBuilderName(stateBuilderId uint64) *C.char {
	stateBuilder := GetComponent(stateBuilderId, StateBuilderTypeId).(StateBuilder)
	return C.CString(stateBuilder.Name())
}

//export StateBuilderBuild
func StateBuilderBuild(stateBuilderId uint64) uint64 {
	stateBuilder := GetComponent(stateBuilderId, StateBuilderTypeId).(StateBuilder)
	state := stateBuilder.Build()
	return AddComponent(state, StateTypeId)
}
