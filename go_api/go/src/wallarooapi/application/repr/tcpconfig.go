package repr

func MakeTCPSourceConfig(host string, port string, decoderId uint64) *TCPSourceConfig {
	return &TCPSourceConfig{"TCPSource", host, port, decoderId}
}

type TCPSourceConfig struct {
	Class     string
	Host      string
	Port      string
	DecoderId uint64
}

func MakeTCPSinkConfig(host string, port string, encoderId uint64) *TCPSinkConfig {
	return &TCPSinkConfig{"TCPSink", host, port, encoderId}
}

type TCPSinkConfig struct {
	Class     string
	Host      string
	Port      string
	EncoderId uint64
}
