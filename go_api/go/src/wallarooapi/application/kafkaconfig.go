package application

import (
	wa "wallarooapi"
	"wallarooapi/application/repr"
)

func brokersRepr(brokers []*KafkaHostPort) []*repr.KafkaHostPort {
	brokers_repr := make([]*repr.KafkaHostPort, 0)
	for _, b := range brokers {
		brokers_repr = append(brokers_repr, b.Repr())
	}
	return brokers_repr
}

func MakeKafkaHostPort(host string, port uint64) *KafkaHostPort {
	return &KafkaHostPort{host, port}
}

type KafkaHostPort struct {
	host string
	port uint64
}

func (khp *KafkaHostPort) Repr() *repr.KafkaHostPort {
	return &repr.KafkaHostPort{khp.host, khp.port}
}

func MakeKafkaSourceConfig(topic string, brokers []*KafkaHostPort, logLevel string, decoder wa.Decoder) *KafkaSourceConfig {
	return &KafkaSourceConfig{topic, brokers, logLevel, decoder, 0}
}

type KafkaSourceConfig struct {
	topic string
	brokers []*KafkaHostPort
	logLevel string
	decoder wa.Decoder
	decoderId uint64
}

func (ksc *KafkaSourceConfig) SourceConfigRepr() interface{} {
	return repr.MakeKafkaSourceConfig(ksc.topic, brokersRepr(ksc.brokers), ksc.logLevel, ksc.decoderId)
}

func (ksc *KafkaSourceConfig) MakeDecoder() repr.ComponentRepresentable {
	return makeDecoder(ksc.addDecoder())
}

func (ksc *KafkaSourceConfig) addDecoder() uint64 {
	ksc.decoderId = wa.AddComponent(ksc.decoder)
	return ksc.decoderId
}

func MakeKafkaSinkConfig(topic string, brokers []*KafkaHostPort, logLevel string,
	maxProduceBufferMs uint64, maxMessageSize uint64, encoder wa.KafkaEncoder) *KafkaSinkConfig {
	return &KafkaSinkConfig{topic, brokers, logLevel, maxProduceBufferMs, maxMessageSize, encoder, 0}
}

type KafkaSinkConfig struct {
	topic string
	brokers []*KafkaHostPort
	logLevel string
	maxProduceBufferMs uint64
	maxMessageSize uint64
	encoder wa.KafkaEncoder
	encoderId uint64
}

func (ksc *KafkaSinkConfig) SinkConfigRepr() interface{} {
	return repr.MakeKafkaSinkConfig(ksc.topic, brokersRepr(ksc.brokers), ksc.logLevel, ksc.maxProduceBufferMs, ksc.maxMessageSize, ksc.encoderId)
}

func (ksc *KafkaSinkConfig) MakeEncoder() repr.ComponentRepresentable {
	return makeEncoder(ksc.addEncoder())
}

func (ksc *KafkaSinkConfig) addEncoder() uint64 {
	ksc.encoderId = wa.AddComponent(ksc.encoder)
	return ksc.encoderId
}
