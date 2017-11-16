package application

import "wallarooapi/application/repr"

func makeComputationMultiBuilder(id uint64) *computationMultiBuilder {
	return &computationMultiBuilder{id}
}

type computationMultiBuilder struct {
	id uint64
}

func (cmb *computationMultiBuilder) Repr() *repr.Component {
	return repr.MakeComputationMultiBuilder(cmb.id)
}

func makeStateComputation(id uint64) *stateComputation {
	return &stateComputation{id}
}

type stateComputation struct {
	id uint64
}

func (sc *stateComputation) Repr() *repr.Component {
	return repr.MakeStateComputation(sc.id)
}

func makeStateBuilder(id uint64) *stateBuilder {
	return &stateBuilder{id}
}

type stateBuilder struct {
	id uint64
}

func (sb *stateBuilder) Repr() *repr.Component {
	return repr.MakeStateBuilder(sb.id)
}

// func makePartitionFunction(id uint64) *partitionFunction {
// 	return &partitionFunction{id}
// }

// type partitionFunction struct {
// 	id uint64
// }

// func (pf *partitionFunction) Repr() *repr.Component {
// 	return repr.MakePartitionFunction(pf.id)
// }

// func makePartition(id uint64) *partition {
// 	return &partition{id}
// }

// type partition struct {
// 	id uint64
// }

// func (p *partition) Repr() *repr.Component {
// 	return repr.MakePartition(p.id)
// }

func makeDecoder(id uint64) *decoder {
	return &decoder{id}
}

type decoder struct {
	id uint64
}

func (d *decoder) Repr() *repr.Component {
	return repr.MakeDecoder(d.id)
}

func makeEncoder(id uint64) *encoder {
	return &encoder{id}
}

type encoder struct {
	id uint64
}

func (e *encoder) Repr() *repr.Component {
	return repr.MakeEncoder(e.id)
}
