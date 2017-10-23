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

func MakeToStatePartition(stepId uint64, fromStepId uint64, stateComputationId uint64, stateBuilderId uint64, stateName string, partitionId uint64, multiWorker bool) interface {} {
	return &ToStatePartition{"ToStatePartition", stepId, fromStepId, stateComputationId, stateBuilderId, stateName, partitionId, multiWorker}
}

type ToStatePartition struct {
	Class string
	StepId uint64
	FromStepId uint64
	StateComputationId uint64
	StateBuilderId uint64
	StateName string
	PartitionId uint64
	MultiWorker bool
}

func MakeToSink(stepId uint64, fromStepId uint64, tcpSinkConfig *TCPSinkConfig) *ToSink {
	return &ToSink{"ToSink", stepId, fromStepId, tcpSinkConfig}
}

type ToSink struct {
	Class string
	StepId uint64
	FromStepId uint64
	Sink *TCPSinkConfig
}
