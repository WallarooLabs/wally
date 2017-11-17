package repr

type ComponentRepresentable interface {
	Repr() *Component
}

type Component struct {
	Class string
	ComponentId uint64
}

func MakeComputationMultiBuilder(id uint64) *Component {
	return &Component{"ComputationMultiBuilder", id}
}

func MakeStateComputation(id uint64) *Component {
	return &Component{"StateComputation", id}
}

func MakeStateBuilder(id uint64) *Component {
	return &Component{"StateBuilder", id}
}

func MakePartitionFunction(id uint64) *Component {
	return &Component{"PartitionFunction", id}
}

func MakeDecoder(id uint64) *Component {
	return &Component{"SourceHandler", id}
}

func MakeFramedDecoder(id uint64) *Component {
	return &Component{"TCPFramedSourceHandler", id}
}

func MakeEncoder(id uint64) *Component {
	return &Component{"Encoder", id}
}
