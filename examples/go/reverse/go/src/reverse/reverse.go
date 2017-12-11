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

  application := app.MakeApplication("Reverse Word")
  application.NewPipeline("Reverse", app.MakeTCPSourceConfig("127.0.0.1", "7010", &Decoder{})).
    To(&RevserseBuilder{}).
    ToStatePartition(&CountWord{}, &WordTotalsBuilder{}, "word totals", &WordPartitionFunction{}, LetterPartition(), true).
    ToSink(app.MakeTCPSinkConfig("127.0.0.1", "7002", &Encoder{}))

  json := application.ToJson()
  fmt.Println(json)

  return C.CString(json)
}
