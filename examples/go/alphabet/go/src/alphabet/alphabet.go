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
  "reflect"
  "strings"
  wa "wallarooapi"
  app "wallarooapi/application"
)

//export ApplicationSetup
func ApplicationSetup() *C.char {
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

  application := app.MakeApplication("Alphabet")
  application.NewPipeline("Alphabet", app.MakeTCPSourceConfig(inHost, inPort, &Decoder{})).
    ToStatePartition(&AddVotes{}, &RunningVotesTotalBuilder{}, "running vote totals", &LetterPartitionFunction{}, MakeLetterPartitions()).
    ToSink(app.MakeTCPSinkConfig(outHost, outPort, &Encoder{}))

  return C.CString(application.ToJson())
}

type AddVotes struct {}

func (av *AddVotes) Name() string {
  return "add votes"
}

func (av *AddVotes) Compute(data interface{}, state interface{}) (interface{}, bool) {
  lv := data.(*LetterAndVotes)
  rvt := state.(*RunningVoteTotal)
  rvt.Update(lv)
  return rvt.GetVotes(), true
}

type LetterAndVotes struct {
  Letter byte
  Votes uint64
}

type RunningVoteTotal struct {
  Letter byte
  Votes uint64
}

func (tv *RunningVoteTotal) Update(votes *LetterAndVotes) {
  tv.Letter = votes.Letter
  tv.Votes += votes.Votes
}

func (tv *RunningVoteTotal) GetVotes() *LetterAndVotes {
  return &LetterAndVotes{tv.Letter, tv.Votes}
}

type RunningVotesTotalBuilder struct {}

func (rvtb *RunningVotesTotalBuilder) Build() interface{} {
  return &RunningVoteTotal{}
}

type LetterPartitionFunction struct {}

func (lpf *LetterPartitionFunction) Partition(data interface{}) uint64 {
  lav := data.(*LetterAndVotes)
  return uint64(lav.Letter)
}

func MakeLetterPartitions() []uint64 {
  letterPartition := make([]uint64, 26)

  for i := 0; i < 26; i++ {
    letterPartition[i] = uint64(i + 'a')
  }

  return letterPartition
}

type Decoder struct {}

func (d *Decoder) HeaderLength() uint64 {
  return 4
}

func (d *Decoder) PayloadLength(b []byte) uint64 {
  return uint64(binary.BigEndian.Uint32(b[0:4]))
}

func (d *Decoder) Decode(b []byte) interface{} {
  letter := b[0]
  vote_count := binary.BigEndian.Uint32(b[1:])

  lav := LetterAndVotes{letter, uint64(vote_count)}
  return &lav
}

type Encoder struct {}

func (encoder *Encoder) Encode(data interface{}) []byte {
  lav := data.(*LetterAndVotes)
  output := fmt.Sprintf("%s => %d\n", string(lav.Letter), lav.Votes)

  return []byte(output)
}

const (
  letterAndVotesType = iota
  runningVoteTotalType
  addVotesType
  runningVotesTotalBuilderType
  letterPartitionFunctionType
  decoderType
  encoderType
)

func Serialize(c interface{}) []byte {
  switch t := c.(type) {

  case *LetterAndVotes:
    buff := make([]byte, 4)
    binary.BigEndian.PutUint32(buff, letterAndVotesType)
    var b bytes.Buffer
    enc := gob.NewEncoder(&b)
    enc.Encode(c)
    return append(buff, b.Bytes()...)

    /*lav := c.(*LetterAndVotes)
    buff := make([]byte, 13)
    binary.BigEndian.PutUint32(buff, letterAndVotesType)
    buff[4] = lav.Letter
    binary.BigEndian.PutUint64(buff, lav.Votes)
    return buff*/
  case *RunningVoteTotal:
    buff := make([]byte, 4)
    binary.BigEndian.PutUint32(buff, runningVoteTotalType)
    var b bytes.Buffer
    enc := gob.NewEncoder(&b)
    enc.Encode(c)
    return append(buff, b.Bytes()...)
    /*rvt := c.(*RunningVoteTotal)
    buff := make([]byte, 13)
    binary.BigEndian.PutUint32(buff, runningVoteTotalType)
    buff[4] = rvt.Letter
    binary.BigEndian.PutUint64(buff, rvt.Votes)
    return buff*/
  case *AddVotes:
    buff := make([]byte, 4)
    binary.BigEndian.PutUint32(buff, addVotesType)
    return buff
  case *RunningVotesTotalBuilder:
    buff := make([]byte, 4)
    binary.BigEndian.PutUint32(buff, runningVotesTotalBuilderType)
    return buff
  case *LetterPartitionFunction:
    buff := make([]byte, 4)
    binary.BigEndian.PutUint32(buff, letterPartitionFunctionType)
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
  case letterAndVotesType:
    b := bytes.NewBuffer(payload)
    dec := gob.NewDecoder(b)
    var lav LetterAndVotes
    dec.Decode(&lav)
    return &lav
  case runningVoteTotalType:
    b := bytes.NewBuffer(payload)
    dec := gob.NewDecoder(b)
    var rvt RunningVoteTotal
    dec.Decode(&rvt)
    return &rvt
  case addVotesType:
    return &AddVotes{}
  case runningVotesTotalBuilderType:
    return &RunningVotesTotalBuilder{}
  case letterPartitionFunctionType:
    return &LetterPartitionFunction{}
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

func main() {}
