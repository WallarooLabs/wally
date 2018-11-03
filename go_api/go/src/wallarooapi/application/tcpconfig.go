package application

import (
	wa "wallarooapi"
	"wallarooapi/application/repr"
)

type TCPSourceConfig struct {
	host      string
	port      string
	decoder   wa.Decoder
	decoderId uint64
}

func MakeTCPSourceConfig(host string, port string, decoder wa.Decoder) *TCPSourceConfig {
	return &TCPSourceConfig{host, port, decoder, 0}
}

func (tsc *TCPSourceConfig) MakeDecoder() repr.ComponentRepresentable {
	return makeFramedDecoder(tsc.addDecoder())
}

func (tsc *TCPSourceConfig) addDecoder() uint64 {
	tsc.decoderId = wa.AddComponent(tsc.decoder, wa.DecoderTypeId)
	return tsc.decoderId
}

func (tsc *TCPSourceConfig) SourceConfigRepr() interface{} {
	return repr.MakeTCPSourceConfig(tsc.host, tsc.port, tsc.decoderId)
}

type TCPSinkConfig struct {
	host      string
	port      string
	encoder   wa.Encoder
	encoderId uint64
}

func MakeTCPSinkConfig(host string, port string, encoder wa.Encoder) *TCPSinkConfig {
	return &TCPSinkConfig{host, port, encoder, 0}
}

func (tsc *TCPSinkConfig) MakeEncoder() repr.ComponentRepresentable {
	return makeEncoder(tsc.addEncoder())
}

func (tsc *TCPSinkConfig) addEncoder() uint64 {
	tsc.encoderId = wa.AddComponent(tsc.encoder, wa.EncoderTypeId)
	return tsc.encoderId
}

func (tsc *TCPSinkConfig) SinkConfigRepr() interface{} {
	return repr.MakeTCPSinkConfig(tsc.host, tsc.port, tsc.encoderId)
}
