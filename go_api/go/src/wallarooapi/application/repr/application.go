package repr

func MakeApplication(name string) *Application {
	return &Application{"Application", name, make([]*Pipeline, 0)}
}

type Application struct {
	Class string
	Name string
	Pipelines []*Pipeline
}

func (app *Application) AddPipeline(pipeline *Pipeline) {
	app.Pipelines = append(app.Pipelines, pipeline)
}

func MakePipeline(name string) *Pipeline {
	return &Pipeline{"Pipeline", name, make([]*Partition, 0), make([]*Component, 0), make([]interface{}, 0), nil}
}

type Pipeline struct {
	Class string
	Name string
	Partitions []*Partition
	Components []*Component
	Connections []interface{}
 	Source interface{}
}

func (p *Pipeline) AddPartition(partition *Partition) {
	p.Partitions = append(p.Partitions, partition)
}

func (p *Pipeline) AddComponent(c *Component) {
	p.Components = append(p.Components, c)
}

func (p *Pipeline) AddSourceConfig(sc interface{}) {
	p.Source = sc
}

func (p *Pipeline) AddConnection(connection interface{}) {
	p.Connections = append(p.Connections, connection)
}

// func makeTCPConfig(host string, port string) *tcpConfig {
// 	return &tcpConfig{"TCPConfig", host, port}
// }

// type tcpConfig struct {
// 	Class string
// 	Host string
// 	Port string
// }
