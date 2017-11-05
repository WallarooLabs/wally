package wallarooapi

import "C"

type ApplicationBuilder struct {}

func MakeApplicationBuilder() *ApplicationBuilder {
	return &ApplicationBuilder{}
}

func (ab *ApplicationBuilder) ToJson() string {
	return "{}"
}
