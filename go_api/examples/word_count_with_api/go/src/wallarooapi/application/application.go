package application

import r "repr"

func MakeApplication(name string) *application {
	return &application{r.MakeApplication(name)}
}

type application struct {
	repr r.Application
}

func (app *application) NewPipeline(name string, SourceConfig interface{}) {
	app.r.Pipelines = append(app.r.Pipelines, sourceConfig.repr, repr.MakePipeline(name))
}

func (app *application) ToJson() string {
	j, _ := json.Marshal(app.repr)
	return string(j)
}

func makePipelineBuilder(app *application) {
}
