package wallarooapi

import "C"

type Computation interface {
	Name() string
	Compute(data interface{}) interface {}
}

//export ComputationName
func ComputationName(computationId uint64) *C.char {
	computation := GetComponent(computationId).(Computation)
	return C.CString(computation.Name())
}

//export ComputationCompute
func ComputationCompute(computationId uint64, dataId uint64) uint64 {
	computation := GetComponent(computationId).(Computation)
	data := GetComponent(dataId).(interface{})
	res := computation.Compute(data)
	if res == nil {
		return 0
	}
	return AddComponent(res)
}

type ComputationBuilder interface {
	Build() interface{}
}

//export ComputationBuilderBuild
func ComputationBuilderBuild(computationBuilderId uint64) uint64 {
	computationBuilder := GetComponent(computationBuilderId).(ComputationBuilder)
	return AddComponent(computationBuilder.Build())
}

type ComputationMulti interface {
	Name() string
	Compute(data interface{}) []interface {}
}

//export ComputationMultiName
func ComputationMultiName(computationId uint64) *C.char {
	computation := GetComponent(computationId).(ComputationMulti)
	return C.CString(computation.Name())
}

//export ComputationMultiCompute
func ComputationMultiCompute(computationId uint64, dataId uint64, size *uint64) uint64 {
	computation := GetComponent(computationId).(ComputationMulti)
	data := GetComponent(dataId).(interface{})
	res := computation.Compute(data)
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

//export GetMultiResultItem
func GetMultiResultItem(resultId uint64, idx uint64) uint64 {
	return (GetComponent(resultId).([]uint64))[idx]
}

type ComputationMultiBuilder interface {
	Build() interface{}
}

//export ComputationMultiBuilderBuild
func ComputationMultiBuilderBuild(computationBuilderId uint64) uint64 {
	computationBuilder := GetComponent(computationBuilderId).(ComputationMultiBuilder)
	return AddComponent(computationBuilder.Build())
}
