package wallarooapi

import "C"

type Computation interface {
	Name() string
	Compute(data interface{}) interface {}
}

//export ComputationName
func ComputationName(computation_id uint64) *C.char {
	computation := GetComponent(computation_id).(Computation)
	return C.CString(computation.Name())
}

//export ComputationCompute
func ComputationCompute(computation_id uint64, data_id uint64) uint64 {
	computation := GetComponent(computation_id).(Computation)
	data := GetComponent(data_id).(interface{})
	res := computation.Compute(data)
	if res == nil {
		return 0
	}
	return AddComponent(res)
}

type ComputationMulti interface {
	Name() string
	Compute(data interface{}) []interface {}
}

//export ComputationMultiName
func ComputationMultiName(computation_id uint64) *C.char {
	computation := GetComponent(computation_id).(ComputationMulti)
	return C.CString(computation.Name())
}

//export ComputationMultiCompute
func ComputationMultiCompute(computation_id uint64, data_id uint64, size *uint64) uint64 {
	computation := GetComponent(computation_id).(ComputationMulti)
	data := GetComponent(data_id).(interface{})
	res := computation.Compute(data)
	if res == nil {
		return 0
	}

	*size = uint64(len(res))
	res_holder := make([]uint64, len(res))

	for i, r := range res {
		res_holder[i] = AddComponent(r)
	}

	return AddComponent(res_holder)
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
	computation_builder := GetComponent(computationBuilderId).(ComputationMultiBuilder)
	return AddComponent(computation_builder.Build())
}
