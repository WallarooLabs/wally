package repr

type ConnectionRepresentable interface {
	Repr() interface{}
}

func MakeTo(stepId uint64, fromStepId uint64, computationBuilderId uint64) interface{} {
	return &To{"ToComputation", stepId, fromStepId, computationBuilderId}
}

type To struct {
	Class string
	StepId uint64
	FromStepId uint64
	ComputationBuilderId uint64
}

func MakeToStatePartition(stepId uint64, fromStepId uint64, stateComputationId uint64, stateBuilderId uint64, stateName string, partitionId uint64) interface {} {
	return &ToStatePartition{"ToStatePartition", stepId, fromStepId, stateComputationId, stateBuilderId, stateName, partitionId}
}

type ToStatePartition struct {
	Class string
	StepId uint64
	FromStepId uint64
	StateComputationId uint64
	StateBuilderId uint64
	StateName string
	PartitionId uint64
}

func MakeToSink(stepId uint64, fromStepId uint64, sinkConfig interface{}) *ToSink {
	return &ToSink{"ToSink", stepId, fromStepId, sinkConfig}
}

type ToSink struct {
	Class string
	StepId uint64
	FromStepId uint64
	Sink interface{}
}

func MakeDone(stepId uint64, fromStepId uint64) *Done {
	return &Done{"Done", stepId, fromStepId}
}

type Done struct {
	Class string
	StepId uint64
	FromStepId uint64
}
