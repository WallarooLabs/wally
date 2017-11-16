package application

import (
	wa "wallarooapi"
	"wallarooapi/application/repr"
)

type TCPSourceConfig struct {
	host string
	port string
	decoder wa.Decoder
	decoderId uint64
}

func MakeTCPSourceConfig(host string, port string, decoder wa.Decoder) *TCPSourceConfig {
	return &TCPSourceConfig{host, port, decoder, 0}
}

func (tsc *TCPSourceConfig) AddDecoder() uint64 {
	tsc.decoderId = wa.AddComponent(tsc.decoder)
	return tsc.decoderId
}

func (tsc *TCPSourceConfig) Repr() *repr.TCPSourceConfig {
	return repr.MakeTCPSourceConfig(tsc.host, tsc.port, tsc.decoderId)
}

type TCPSinkConfig struct  {
	host string
	port string
	encoder wa.Encoder
	encoderId uint64
}

func MakeTCPSinkConfig(host string, port string, encoder wa.Encoder) *TCPSinkConfig {
	return &TCPSinkConfig{host, port, encoder, 0}
}

func (tsc *TCPSinkConfig) AddEncoder() uint64 {
	tsc.encoderId = wa.AddComponent(tsc.encoder)
	return tsc.encoderId
}

func (tsc *TCPSinkConfig) Repr() *repr.TCPSinkConfig {
	return repr.MakeTCPSinkConfig(tsc.host, tsc.port, tsc.encoderId)
}
