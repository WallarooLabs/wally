# Copyright 2019 The Wallaroo Authors.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
#  implied. See the License for the specific language governing
#  permissions and limitations under the License.


from integration.errors import TimeoutError

def data_in_sink_contains(data, timeout=30, sink=-1):
    def data_in_sink_contains_func(context):
        context.sink_await(data, timeout=timeout, func=context.parse_output,
                           sink=sink)
        return True
    return data_in_sink_contains_func


def data_in_sink_count_is(expected, timeout=30, sink=-1, allow_more=False):
    def data_in_sink_count_is_func(context):
        context.sink_expect(expected, timeout=timeout, sink=sink,
                            allow_more=allow_more)
        return True
    return data_in_sink_count_is_func
