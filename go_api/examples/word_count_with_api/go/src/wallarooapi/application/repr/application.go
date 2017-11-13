package repr

import "encoding/json"

func MakeApplication(name string) *application {
	return &application{"Application", name, make([]pipeline, 0)}
}

type application struct {
	Class string
	Name string
	Pipelines []pipeline
}

func (app *application) NewPipeline(name string, sourceConfig interface{}) {
	app.Pipelines = append(app.Pipelines, sourceConfig, makePipeline(name))
}

func makePipeline(name string) pipeline {
	return pipeline{"Pipeline", name}
}

type pipeline struct {
	Class string
	Name string
	SourceConfig interface{}
}

func makeTCPConfig(host string, port string) tcpConfig {
	return tcpConfig{"TCPConfig", host, port}
}

type tcpConfig struct {
	Class string
	Host string
	Port string
}
