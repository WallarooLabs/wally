package application

import "wallarooapi/application/repr"

type SinkConfig interface {
	SinkConfigRepr() interface{}
	MakeEncoder() repr.ComponentRepresentable
}
