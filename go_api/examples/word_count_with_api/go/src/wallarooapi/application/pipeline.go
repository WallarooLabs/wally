package application

import "wallarooapi/application/repr"

func makePipeline(name string, sourceConfig *TCPSourceConfig) *pipeline {
	p := &pipeline{name, sourceConfig, make([]*Partition, 0), make([]repr.ComponentRepresentable, 0), make([]repr.ConnectionRepresentable, 0)}
	p.AddTCPSourceConfig(sourceConfig)
	return p
}

type pipeline struct {
	name string
	sourceConfig *TCPSourceConfig
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

	p_repr.AddTCPSourceConfig(p.sourceConfig.Repr())
	return p_repr
}

func (p *pipeline) AddTCPSourceConfig(sourceConfig *TCPSourceConfig) {
	p.components = append(p.components, makeDecoder(sourceConfig.AddDecoder()))
}

func (p *pipeline) AddDecoder(decoderId uint64) {
	makeDecoder(decoderId)
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

func (p *pipeline) AddToSink(fromStepId uint64, sinkConfig *TCPSinkConfig) uint64 {
	p.components = append(p.components, makeEncoder(sinkConfig.AddEncoder()))
	newStepId := p.newStepId()
	p.connections = append(p.connections, makeToSink(newStepId, fromStepId, sinkConfig))
	return newStepId
}
