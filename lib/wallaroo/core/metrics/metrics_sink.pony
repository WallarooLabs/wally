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

use "wallaroo/core/common"

interface tag MetricsSink is DisposableActor
  be send_metrics(metrics: MetricDataList val)
  fun ref set_nodelay(state: Bool)
  be writev(data: ByteSeqIter)
  fun ref set_so_sndbuf(bufsiz: U32): U32 =>
    """
    This impl. is only for use as fallback by test classes.
    """
    0
