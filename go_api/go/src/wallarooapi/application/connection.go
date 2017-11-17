package application

import "wallarooapi/application/repr"

type Step struct {
	stepId uint64
	fromStepId uint64
}

func makeTo(stepId uint64, fromStepId uint64, computationBuilderId uint64) *To {
	return &To{&Step{stepId, fromStepId}, computationBuilderId}
}

type To struct {
	*Step
	computationBuilderId uint64
}

func (to *To) Repr() interface{} {
	return repr.MakeTo(to.stepId, to.fromStepId, to.computationBuilderId)
}

func makeToStatePartition(stepId uint64, fromStepId uint64, stateComputationId uint64, stateBuilderId uint64, stateName string, partitionFunctionId uint64, partitionId uint64, multiWorker bool) *ToStatePartition {
	return &ToStatePartition{&Step{stepId, fromStepId}, stateComputationId, stateBuilderId, stateName, partitionFunctionId, partitionId, multiWorker}
}

type ToStatePartition struct {
	*Step
	stateComputationId uint64
	stateBuilderId uint64
	stateName string
	partitionFunctionId uint64
	partitionId uint64
	multiWorker bool
}

func (tsp *ToStatePartition) Repr() interface{} {
	return repr.MakeToStatePartition(tsp.stepId, tsp.fromStepId, tsp.stateComputationId, tsp.stateBuilderId, tsp.stateName, tsp.partitionId, tsp.multiWorker)
}

func makeToSink(stepId uint64, fromStepId uint64, sinkConfig SinkConfig) *ToSink {
	return &ToSink{&Step{stepId, fromStepId}, sinkConfig}
}

type ToSink struct {
	*Step
	SinkConfig SinkConfig
}

func (ts *ToSink) Repr() interface{} {
	return repr.MakeToSink(ts.stepId, ts.fromStepId, ts.SinkConfig.SinkConfigRepr())
}
