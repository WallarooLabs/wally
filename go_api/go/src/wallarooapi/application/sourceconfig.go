package application

import "wallarooapi/application/repr"

type SourceConfig interface {
	SourceConfigRepr() interface{}
	MakeDecoder() repr.ComponentRepresentable
}
