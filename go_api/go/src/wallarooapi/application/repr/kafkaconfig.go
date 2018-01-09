package repr

func MakeKafkaHostPort(host string, port uint64) *KafkaHostPort {
	return &KafkaHostPort{host, port}
}

type KafkaHostPort struct {
	Host string
	Port uint64
}

func MakeKafkaSourceConfig(topic string, brokers []*KafkaHostPort, logLevel string, decoderId uint64) *KafkaSourceConfig {
	return &KafkaSourceConfig{"KafkaSource", topic, brokers, logLevel, decoderId}
}

type KafkaSourceConfig struct {
	Class string
	Topic string
	Brokers []*KafkaHostPort
	LogLevel string
	DecoderId uint64
}

func MakeKafkaSinkConfig(topic string, brokers []*KafkaHostPort, logLevel string,
	maxProduceBufferMs uint64, maxMessageSize uint64, encoderId uint64) *KafkaSinkConfig {
	return &KafkaSinkConfig{"KafkaSink", topic, brokers, logLevel, maxProduceBufferMs, maxMessageSize, encoderId}
}

type KafkaSinkConfig struct {
	Class string
	Topic string
	Brokers []*KafkaHostPort
	LogLevel string
	MaxProduceBufferMs uint64
	MaxMessageSize uint64
	EncoderId uint64
}
