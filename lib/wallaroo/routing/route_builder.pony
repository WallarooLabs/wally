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

use "wallaroo/boundary"
use "wallaroo/core/common"
use "wallaroo/ent/data_receiver"
use "wallaroo/fail"
use "wallaroo/metrics"
use "wallaroo/topology"

trait val RouteBuilder
  fun apply(step: Producer ref, consumer: Consumer,
    metrics_reporter: MetricsReporter ref): Route

primitive TypedRouteBuilder[In: Any val] is RouteBuilder
  fun apply(step: Producer ref, consumer: Consumer,
    metrics_reporter: MetricsReporter ref): Route
  =>
    match consumer
    | let boundary: OutgoingBoundary =>
      BoundaryRoute(step, boundary, consume metrics_reporter)
    else
      TypedRoute[In](step, consumer, consume metrics_reporter)
    end

primitive BoundaryOnlyRouteBuilder is RouteBuilder
  fun apply(step: Producer ref, consumer: Consumer,
    metrics_reporter: MetricsReporter ref): Route
  =>
    match consumer
    | let boundary: OutgoingBoundary =>
      BoundaryRoute(step, boundary, consume metrics_reporter)
    else
      Fail()
      EmptyRoute
    end

