// Copyright 2017 The Wallaroo Authors.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
//  implied. See the License for the specific language governing
//  permissions and limitations under the License.

package main

import (
	"C"
	"bytes"
	"encoding/binary"
	"encoding/gob"
	"fmt"
	"reflect"
	wa "wallarooapi"
	app "wallarooapi/application"
)

//export ApplicationSetup
func ApplicationSetup() *C.char {
	wa.Serialize = Serialize
	wa.Deserialize = Deserialize

	application := app.MakeApplication("Reverse Word")
	application.NewPipeline("Reverse", app.MakeKafkaSourceConfig("kafka_source", &Decoder{})).
		To(&ReverseBuilder{}).
		ToSink(app.MakeKafkaSinkConfig("kafka_sink", &Encoder{}))

	return C.CString(application.ToJson())
}

type ReverseBuilder struct{}

func (rb *ReverseBuilder) Build() interface{} {
	return &Reverse{}
}

type Reverse struct{}

func (r *Reverse) Name() string {
	return "reverse"
}

func (r *Reverse) Compute(data interface{}) interface{} {
	input := *(data.(*string))

	// string reversal taken from
	// https://groups.google.com/forum/#!topic/golang-nuts/oPuBaYJ17t4

	n := 0
	rune := make([]rune, len(input))
	for _, r := range input {
		rune[n] = r
		n++
	}
	rune = rune[0:n]
	// Reverse
	for i := 0; i < n/2; i++ {
		rune[i], rune[n-1-i] = rune[n-1-i], rune[i]
	}
	// Convert back to UTF-8.
	output := string(rune)

	return output
}

type Decoder struct{}

func (d *Decoder) Decode(b []byte) interface{} {
	x := string(b[:])
	return &x
}

type Encoder struct{}

func (e *Encoder) Encode(data interface{}) ([]byte, []byte, int32) {
	msg := data.(string)
	return []byte(msg), nil, -1
}

const (
	stringType = iota
	reverseType
	reverseBuilderType
	decoderType
	encoderType
)

func Serialize(c interface{}) []byte {
	switch t := c.(type) {
	case *string:
		buff := make([]byte, 4)
		binary.BigEndian.PutUint32(buff, stringType)
		var b bytes.Buffer
		enc := gob.NewEncoder(&b)
		enc.Encode(c)
		return append(buff, b.Bytes()...)
	case *Reverse:
		buff := make([]byte, 4)
		binary.BigEndian.PutUint32(buff, reverseType)
		return buff
	case *ReverseBuilder:
		buff := make([]byte, 4)
		binary.BigEndian.PutUint32(buff, reverseBuilderType)
		return buff
	case *Decoder:
		buff := make([]byte, 4)
		binary.BigEndian.PutUint32(buff, decoderType)
		return buff
	case *Encoder:
		buff := make([]byte, 4)
		binary.BigEndian.PutUint32(buff, encoderType)
		return buff
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
	case stringType:
		b := bytes.NewBuffer(payload)
		dec := gob.NewDecoder(b)
		var s string
		dec.Decode(&s)
		return &s
	case reverseType:
		return &Reverse{}
	case reverseBuilderType:
		return &ReverseBuilder{}
	case decoderType:
		return &Decoder{}
	case encoderType:
		return &Encoder{}
	default:
		fmt.Println("DESERIALIZE MISSED A CASE")
	}

	return nil
}

func main() {
}
