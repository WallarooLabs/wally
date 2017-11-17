package application

import "wallarooapi/application/repr"

func makePipeline(name string, sourceConfig SourceConfig) *pipeline {
	p := &pipeline{name, sourceConfig, make([]*Partition, 0), make([]repr.ComponentRepresentable, 0), make([]repr.ConnectionRepresentable, 0)}
	p.AddSourceConfig(sourceConfig)
	return p
}

type pipeline struct {
	name string
	sourceConfig SourceConfig
	partitions []*Partition
	components []repr.ComponentRepresentable
	connections []repr.ConnectionRepresentable
}

func (p *pipeline) newStepId() uint64 {
	return uint64(len(p.connections) + 1)
}

func (p *pipeline) repr() *repr.Pipeline {
	p_repr := repr.MakePipeline(p.name)

	for partition_idx, partition := range p.partitions {
		p_repr.AddPartition(partition.Repr(uint64(partition_idx)))
	}

	for _, c := range p.components {
		p_repr.AddComponent(c.Repr())
	}

	for _, conn := range p.connections {
		p_repr.AddConnection(conn.Repr())
	}

	p_repr.AddSourceConfig(p.sourceConfig.SourceConfigRepr())
	return p_repr
}

func (p *pipeline) AddSourceConfig(sourceConfig SourceConfig) {
	p.components = append(p.components, sourceConfig.MakeDecoder())
}

func (p *pipeline) AddToComputationMulti(fromStepId uint64, id uint64) uint64 {
	p.components = append(p.components, makeComputationMultiBuilder(id))
	newStepId := p.newStepId()
	p.connections = append(p.connections, makeTo(newStepId, fromStepId, id))
	return newStepId
}

func (p *pipeline) AddToStatePartition(fromStepId uint64, computationId uint64, stateBuilderId uint64, stateName string, partitionFunctionId uint64, partitionListId uint64, multiWorker bool) uint64 {
	p.components = append(p.components, makeStateComputation(computationId))
	p.components = append(p.components, makeStateBuilder(stateBuilderId))
	partitionId := uint64(len(p.partitions))
	p.partitions = append(p.partitions, MakePartition(partitionFunctionId, partitionListId))
	newStepId := p.newStepId()
	p.connections = append(p.connections, makeToStatePartition(newStepId, fromStepId, computationId, stateBuilderId, stateName, partitionFunctionId, partitionId, multiWorker))
	return newStepId
}

func (p *pipeline) AddToSink(fromStepId uint64, sinkConfig SinkConfig) uint64 {
	p.components = append(p.components, sinkConfig.MakeEncoder())
	newStepId := p.newStepId()
	p.connections = append(p.connections, makeToSink(newStepId, fromStepId, sinkConfig))
	return newStepId
}
