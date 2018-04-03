package repr

func MakeKafkaSourceConfig(name string, decoderId uint64) *KafkaSourceConfig {
	return &KafkaSourceConfig{"KafkaSource", name, decoderId}
}

type KafkaSourceConfig struct {
	Class string
	Name string
	DecoderId uint64
}

func MakeKafkaSinkConfig(name string, encoderId uint64) *KafkaSinkConfig {
	return &KafkaSinkConfig{"KafkaSink", name, encoderId}
}

type KafkaSinkConfig struct {
	Class string
	Name string
	EncoderId uint64
}
