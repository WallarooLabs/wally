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
  "bytes"
  "C"
  "encoding/binary"
  "encoding/gob"
  "flag"
  "fmt"
  "math"
  "reflect"
    "strings"
  wa "wallarooapi"
  app "wallarooapi/application"
)

//export ApplicationSetup
func ApplicationSetup(showHelp bool) *C.char {
  fs := flag.NewFlagSet("wallaroo", flag.ExitOnError)
  inHostsPortsArg := fs.String("in", "", "input host:port list")
  outHostsPortsArg := fs.String("out", "", "output host:port list")

  fs.Parse(wa.Args[1:])

  inHostsPorts := hostsPortsToList(*inHostsPortsArg)

  inHost := inHostsPorts[0][0]
  inPort := inHostsPorts[0][1]

  outHostsPorts := hostsPortsToList(*outHostsPortsArg)
  outHost := outHostsPorts[0][0]
  outPort := outHostsPorts[0][1]

  wa.Serialize = Serialize
  wa.Deserialize = Deserialize

  application := app.MakeApplication("Celsius to Fahrenheit")
  application.NewPipeline("Celsius Conversion", app.MakeTCPSourceConfig(inHost, inPort, &Decoder{})).
    To(&MultiplyBuilder{}).
    To(&AddBuilder{}).
    ToSink(app.MakeTCPSinkConfig(outHost, outPort, &Encoder{}))

  return C.CString(application.ToJson())
}

type MultiplyBuilder struct {}

func (rb *MultiplyBuilder) Build() interface{} {
  return &Multiply{}
}

type Multiply struct {}

func (r *Multiply) Name() string {
  return "multiply by 1.8"
}

func (r *Multiply) Compute(data interface{}) interface{} {
  input := (data.(float32))

  return input * 1.8
}

type AddBuilder struct {}

func (rb *AddBuilder) Build() interface{} {
  return &Add{}
}

type Add struct {}

func (r *Add) Name() string {
  return "add 32"
}

func (r *Add) Compute(data interface{}) interface{} {
  input := (data.(float32))

  return input + 32.0
}

type Decoder struct {}

func (d *Decoder) HeaderLength() uint64 {
  return 4
}

func (d *Decoder) PayloadLength(b []byte) uint64 {
  return uint64(binary.BigEndian.Uint32(b[0:4]))
}

func (d* Decoder) Decode(b []byte) interface{} {
  return float32FromByteSlice(b)
}

type Encoder struct {}

func (e *Encoder) Encode(data interface{}) []byte {
  msg := data.(float32)
  s := fmt.Sprintf("%.6f", msg)
  return []byte(s + "\n")
}

const (
  float32Type = iota
  multiplyType
  multiplyBuilderType
  addType
  addBuilderType
  decoderType
  encoderType
)

func Serialize(c interface{}) []byte {
  switch t := c.(type) {
  case float32:
    buff := make([]byte, 4)
    binary.BigEndian.PutUint32(buff, float32Type)
    var b bytes.Buffer
    enc := gob.NewEncoder(&b)
    enc.Encode(c)
    return append(buff, b.Bytes()...)
  case *Multiply:
     buff := make([]byte, 4)
    binary.BigEndian.PutUint32(buff, multiplyType)
    return buff
  case *MultiplyBuilder:
    buff := make([]byte, 4)
    binary.BigEndian.PutUint32(buff, multiplyBuilderType)
    return buff
  case *Add:
     buff := make([]byte, 4)
    binary.BigEndian.PutUint32(buff, addType)
    return buff
  case *AddBuilder:
    buff := make([]byte, 4)
    binary.BigEndian.PutUint32(buff, addBuilderType)
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
  case float32Type:
    b := bytes.NewBuffer(payload)
    dec := gob.NewDecoder(b)
    var f float32
    dec.Decode(&f)
    return f
  case multiplyType:
    return &Multiply{}
  case multiplyBuilderType:
    return &MultiplyBuilder{}
  case addType:
    return &Add{}
  case addBuilderType:
    return &AddBuilder{}
  case decoderType:
    return &Decoder{}
  case encoderType:
    return &Encoder{}
  default:
    fmt.Println("DESERIALIZE MISSED A CASE")
  }

  return nil
}

func hostsPortsToList(hostsPorts string) [][]string {
  hostsPortsList := make([][]string, 0)
  for _, hp := range strings.Split(hostsPorts, ",") {
    hostsPortsList = append(hostsPortsList, strings.Split(hp, ":"))
  }
  return hostsPortsList
}

func float32FromByteSlice(buff []byte) float32 {
  bits := binary.BigEndian.Uint32(buff)
  float := math.Float32frombits(bits)

  return float
}

func main() {
}
