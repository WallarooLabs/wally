package application

import (
	"encoding/json"
	wa "wallarooapi"
	"wallarooapi/application/repr"
)

func MakeApplication(name string) *application {
	return &application{name, make([]*pipeline, 0)}
}

type application struct {
	name string
	pipelines []*pipeline
}

func (app *application) repr() *repr.Application {
	appRepr := repr.MakeApplication(app.name)

	for _, pipeline := range app.pipelines {
		appRepr.AddPipeline(pipeline.repr())
	}
	return appRepr
}

func (app *application) NewPipeline(name string, sourceConfig SourceConfig) *pipelineBuilder {
	p := makePipeline(name, sourceConfig)
	app.pipelines = append(app.pipelines, p)
	return makePipelineBuilder(0, app, p)
}

func (app *application) ToJson() string {
	j, _ := json.Marshal(app.repr())
	return string(j)
}

func makePipelineBuilder(lastStepId uint64, app *application, pipeline *pipeline) *pipelineBuilder {
	return &pipelineBuilder{lastStepId, app, pipeline}
}

type pipelineBuilder struct {
	lastStepId uint64
	app *application
	pipeline *pipeline
}

func (pb *pipelineBuilder) ToMulti(computationBuilder wa.ComputationMultiBuilder) *pipelineBuilder {
	id := wa.AddComponent(computationBuilder)
	newStepId := pb.pipeline.AddToComputationMulti(pb.lastStepId, id)
	return makePipelineBuilder(newStepId, pb.app, pb.pipeline)
}

func (pb *pipelineBuilder) ToStatePartition(stateComputation wa.StateComputation, stateBuilder wa.StateBuilder, stateName string, partitionFunction wa.PartitionFunction, partitions []uint64, multiWorker bool) *pipelineBuilder {
	computationId := wa.AddComponent(stateComputation)
	stateBuilderId := wa.AddComponent(stateBuilder)
	partitionFunctionId := wa.AddComponent(partitionFunction)
	partitionId := wa.AddComponent(partitions)
	newStepId := pb.pipeline.AddToStatePartition(pb.lastStepId, computationId, stateBuilderId, stateName, partitionFunctionId, partitionId, multiWorker)
	return makePipelineBuilder(newStepId, pb.app, pb.pipeline)
}

func (pb *pipelineBuilder) ToSink(sinkConfig SinkConfig) *pipelineBuilder {
	newStepId := pb.pipeline.AddToSink(pb.lastStepId, sinkConfig)
	return makePipelineBuilder(newStepId, pb.app, pb.pipeline)
}

func (pb *pipelineBuilder) Done() {
	pb.pipeline.AddDone(pb.lastStepId)
}
