package application

import (
	wa "wallarooapi"
	"wallarooapi/application/repr"
)

func MakeKafkaSourceConfig(name string, decoder wa.Decoder) *KafkaSourceConfig {
	return &KafkaSourceConfig{name, decoder, 0}
}

type KafkaSourceConfig struct {
	name string
	decoder wa.Decoder
	decoderId uint64
}

func (ksc *KafkaSourceConfig) SourceConfigRepr() interface{} {
	return repr.MakeKafkaSourceConfig(ksc.name, ksc.decoderId)
}

func (ksc *KafkaSourceConfig) MakeDecoder() repr.ComponentRepresentable {
	return makeDecoder(ksc.addDecoder())
}

func (ksc *KafkaSourceConfig) addDecoder() uint64 {
	ksc.decoderId = wa.AddComponent(ksc.decoder, wa.DecoderTypeId)
	return ksc.decoderId
}

func MakeKafkaSinkConfig(name string, encoder wa.KafkaEncoder) *KafkaSinkConfig {
	return &KafkaSinkConfig{name, encoder, 0}
}

type KafkaSinkConfig struct {
	name string
	encoder wa.KafkaEncoder
	encoderId uint64
}

func (ksc *KafkaSinkConfig) SinkConfigRepr() interface{} {
	return repr.MakeKafkaSinkConfig(ksc.name, ksc.encoderId)
}

func (ksc *KafkaSinkConfig) MakeEncoder() repr.ComponentRepresentable {
	return makeEncoder(ksc.addEncoder())
}

func (ksc *KafkaSinkConfig) addEncoder() uint64 {
	ksc.encoderId = wa.AddComponent(ksc.encoder, wa.EncoderTypeId)
	return ksc.encoderId
}
