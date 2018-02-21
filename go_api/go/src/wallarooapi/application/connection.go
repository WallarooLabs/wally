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

func makeToStatePartition(stepId uint64, fromStepId uint64, stateComputationId uint64, stateBuilderId uint64, stateName string, partitionFunctionId uint64, partitionId uint64) *ToStatePartition {
	return &ToStatePartition{&Step{stepId, fromStepId}, stateComputationId, stateBuilderId, stateName, partitionFunctionId, partitionId}
}

type ToStatePartition struct {
	*Step
	stateComputationId uint64
	stateBuilderId uint64
	stateName string
	partitionFunctionId uint64
	partitionId uint64
}

func (tsp *ToStatePartition) Repr() interface{} {
	return repr.MakeToStatePartition(tsp.stepId, tsp.fromStepId, tsp.stateComputationId, tsp.stateBuilderId, tsp.stateName, tsp.partitionId)
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

func makeToSinks(stepId uint64, fromStepId uint64, sinkConfigs []SinkConfig) *ToSinks {
	return &ToSinks{&Step{stepId, fromStepId}, sinkConfigs}
}

type ToSinks struct {
	*Step
	SinkConfigs []SinkConfig
}

func (ts *ToSinks) Repr() interface{} {
	sinkConfigsRepr := make([]interface{}, 0)
	for _, sc := range ts.SinkConfigs {
		sinkConfigsRepr = append(sinkConfigsRepr, sc.SinkConfigRepr())
	}
	return repr.MakeToSinks(ts.stepId, ts.fromStepId, sinkConfigsRepr)
}

func makeDone(stepId uint64, fromStepId uint64) *Done {
	return &Done{&Step{stepId, fromStepId}}
}

type Done struct {
	*Step
}

func (d *Done) Repr() interface{} {
	return repr.MakeDone(d.stepId, d.fromStepId)
}
