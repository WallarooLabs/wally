package main

import (
	"bytes"
	"C"
	"encoding/binary"
	"encoding/gob"
	"fmt"
	"reflect"
	"strings"
	wa "wallarooapi"
	app "wallarooapi/application"
)

//export ApplicationSetup
func ApplicationSetup() *C.char {
	wa.Serialize = Serialize
	wa.Deserialize = Deserialize
	brokers := []*app.KafkaHostPort{app.MakeKafkaHostPort("127.0.0.1", 9092)}
	application := app.MakeApplication("Word Reverse Application")
	application.NewPipeline("split and reverse", app.MakeKafkaSourceConfig("words", brokers, "Warn", &Decoder{})).
		ToMulti(&SplitBuilder{}).
		// ToSink(app.MakeTCPSinkConfig("127.0.0.1", "7002", &Encoder{}))
		ToSink(app.MakeKafkaSinkConfig("words-out", brokers, "Warn", 1000, 1000, &Encoder{}))
	return C.CString(application.ToJson())
}

type Decoder struct {}

func (decoder *Decoder) Decode(b []byte) interface{} {
	return string(b[:])
}

type Split struct {}

func (s *Split) Name() string {
	return "split"
}

func (s *Split) Compute(data interface{}) []interface{} {
	punctuation := " !\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"
	lines := data.(string)

	words := make([]interface{}, 0)

	for _, line := range strings.Split(lines, "\n") {
		clean_line := strings.Trim(strings.ToLower(line), punctuation)
		for _, word := range strings.Split(clean_line, " ") {
			clean_word := strings.Trim(word, punctuation)
			words = append(words, &clean_word)
		}
	}

	return words
}

type SplitBuilder struct {}

func (sb *SplitBuilder) Build() interface{} {
	return &Split{}
}

type Encoder struct {}

func (encoder *Encoder) Encode(data interface{}) ([]byte, []byte) {
	word := data.(*string)
	msg := fmt.Sprintf("word is '%s'\n", *word)
	fmt.Println(msg)
	return []byte(msg), nil
}

func main () {
}

func Serialize(c interface{}) []byte {
	switch t := c.(type) {
	case *Decoder:
		buff := make([]byte, 4)
		binary.BigEndian.PutUint32(buff, 2)
		return buff
	case *Split:
		buff := make([]byte, 4)
		binary.BigEndian.PutUint32(buff, 3)
		return buff
	case *SplitBuilder:
		buff := make([]byte, 4)
		binary.BigEndian.PutUint32(buff, 4)
		return buff
	case *Encoder:
		buff := make([]byte, 4)
		binary.BigEndian.PutUint32(buff, 9)
		return buff
	case *string:
		buff := make([]byte, 4)
		binary.BigEndian.PutUint32(buff, 10)
		var b bytes.Buffer
		enc := gob.NewEncoder(&b)
		enc.Encode(c)
		return append(buff, b.Bytes()...)
	default:
		fmt.Println("SERIALIZE MISSED A CASE")
		fmt.Println(reflect.TypeOf(t))
	}
	return nil
}

func Deserialize(buff []byte) interface{} {
	componentType := binary.BigEndian.Uint32(buff[:4])
	payload := buff[4:]

	switch componentType {
	case 2:
		return &Decoder{}
	case 3:
		return &Split{}
	case 4:
		return &SplitBuilder{}
	case 9:
		return &Encoder{}
	case 10:
		b := bytes.NewBuffer(payload)
		dec := gob.NewDecoder(b)
		var s string
		dec.Decode(&s)
		return &s
	default:
		fmt.Println("DESERIALIZE MISSED A CASE")
	}
	return nil
}
