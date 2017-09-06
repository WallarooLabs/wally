/*

Copyright 2017 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

use "json"

primitive HubJson
  fun connect(): String =>
    let j: JsonObject = JsonObject
    j.data.update("path", "/socket/tcp")
    j.data.update("params", None)
    j.string(where pretty_print=false)

  fun join(topic: String): String =>
    let j: JsonObject = JsonObject
    j.data.update("event", "phx_join")
    j.data.update("topic", topic)
    j.data.update("ref", None)
    j.data.update("payload", JsonObject)
    j.string(where pretty_print=false)

  fun payload(event: String, topic: String, payload': JsonArray,
    pretty_print: Bool = false): String =>
    let j: JsonObject = JsonObject
    j.data.update("event", event)
    j.data.update("topic", topic)
    j.data.update("ref", None)
    j.data.update("payload", payload')
    j.string(where pretty_print=pretty_print)
