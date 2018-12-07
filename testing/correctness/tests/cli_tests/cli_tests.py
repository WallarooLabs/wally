# Copyright 2018 The Wallaroo Authors.
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

from integration import (Cluster,
                         iter_generator,
                         Reader,
                         Sender)

from integration.external import run_shell_cmd
from integration.logger import set_logging
from integration.test_context import (get_caller_name,
                                      LoggingTestContext)


import os
import json
import time
import struct

INPUT_ITEMS=10
APIS = {'python': 'machida --application-module dummy',
        'python3': 'machida3 --application-module dummy'}

# If resilience is on, add --run-with-resilience to commands
if os.environ.get("resilience") == 'on':
    for api in APIS:
        APIS[api] += ' --run-with-resilience'


def _test_partition_query(command):
    with LoggingTestContext() as ctx:
        with ctx.Cluster(command=command, workers=3) as cluster:
            q = Query(cluster, "partition-query")
            got = q.result()['initializer']

        assert(sorted(["state_partitions","stateless_partitions"]) ==
               sorted(got.keys()))
        for k in got["state_partitions"].keys():
          assert("initializer" in got["state_partitions"][k])


def _test_partition_count_query(command):
    with LoggingTestContext() as ctx:
        with ctx.Cluster(command=command) as cluster:
            given_data_sent(cluster)
            got = Query(cluster, "partition-count-query").result()['initializer']

        assert(sorted(got.keys()) ==
               ["state_partitions", "stateless_partitions"])
        assert(len(got['stateless_partitions']) == 1)
        assert(len(got['state_partitions']) == 2)
        for v in got['state_partitions'].values():
            assert(v['initializer'] == INPUT_ITEMS)


def _test_cluster_status_query(command):
    with LoggingTestContext() as ctx:
        with ctx.Cluster(command=command, workers=2) as cluster:
            q = Query(cluster, "cluster-status-query")
            got = q.result()

        for w in got.values():
            assert(w ==
                   {u"processing_messages": True,
                    u"worker_names": [u"initializer", u"worker1"],
                    u"worker_count": 2})


def _test_source_ids_query(command):
    defined_source_parallelism = 13 # see dummy.py TCPSourceconfig
    with LoggingTestContext() as ctx:
        with ctx.Cluster(command=command, sources=1) as cluster:
            given_data_sent(cluster)
            q = Query(cluster, "source-ids-query")
            got = q.result()['initializer']

        assert(list(got.keys()) == ["source_ids"])
        assert(len(got["source_ids"]) == defined_source_parallelism)


def _test_state_entity_query(command):
    with LoggingTestContext() as ctx:
        with ctx.Cluster(command=command, workers=2) as cluster:
            given_data_sent(cluster)
            got = Query(cluster, "state-entity-query").result()

        # Got queries from two workers
        for k in got:
            assert(len(got[k].keys()) == 2)
        # collect state keys from query results
        part_ids = []
        single_part_id = None
        for w in got.values():
            for v in w.values():
                try:
                    if not v:
                        continue
                    int(v[0])
                    part_ids.extend(v)
                except:
                    single_part_id = v[0]
                    continue
        # Check we have as many state keys as input items
        assert(len(part_ids) == INPUT_ITEMS)
        assert(single_part_id == 'single-partition-key')
        # check that there are two computation ids
        comp_ids = set()
        for w in got.values():
            for key in w:
                comp_ids.add(key)
        assert(len(comp_ids) == 2)


def _test_state_entity_count_query(command):
    with LoggingTestContext() as ctx:
        with ctx.Cluster(command=command, workers=2) as cluster:
            given_data_sent(cluster)
            q = Query(cluster, "state-entity-count-query")
            got = q.result()


        comps = {}
        for w in got.values():
            for k, v in w.items():
                comps[k] = comps.get(k, 0) + v
        assert(set(comps.values()) == set((1,10)))


def _test_stateless_partition_query(command):
    with LoggingTestContext() as ctx:
        with ctx.Cluster(command=command, workers=2) as cluster:
            got = Query(cluster, "stateless-partition-query").result()

        for w, res in got.items():
            for k, v in res.items():
                assert(int(k))
                assert(w in v.keys())
                assert(len(v[w]) == INPUT_ITEMS)


def _test_stateless_partition_count_query(command):
    with LoggingTestContext() as ctx:
        with ctx.Cluster(command=command, workers=2) as cluster:
            got = Query(cluster, "stateless-partition-count-query").result()

        for w, res in got.items():
            for k, v in res.items():
                assert(int(k))
                assert(v == {w : INPUT_ITEMS})


def given_data_sent(cluster):
    values = [chr(x+65) for x in range(INPUT_ITEMS)]
    reader = Reader(iter_generator(values))
    sender = Sender(cluster.source_addrs[0],
                    reader,
                    batch_size=50, interval=0.05, reconnect=True)
    cluster.add_sender(sender, start=True)
    await_values = [struct.pack('>I', len(v.encode())) + v.encode() for v in values]
    cluster.sink_await(await_values)


class Query(object):
    def __init__(self, cluster, query_type):
        cmd = "external_sender --json --external {} --type {}"
        self.cmds = {w.name: cmd.format(w.external, query_type) for w
                     in cluster.workers}

    def result(self):
        res = {k: run_shell_cmd(v) for k,v in self.cmds.items()}
        if all(map(lambda r: r.success, res.values())):
            try:
                return {k: json.loads(v.output) for k, v in res.items()}
            except:
                raise Exception("Failed running parser on {!r}".
                                format(res.output))
        else:
            raise Exception("Failed running cmd: {!r} with {!r}".
                            format(self._cmd, res.output))


def create_test(api, cmd, test_func):
    test_name = 'test_{api}_{test_name}'.format(
        api=api,
        test_name=test_func.__name__[len('_test_'):])
    def f():
        test_func(cmd)
    f.__name__ = test_name
    globals()[test_name] = f


# Create tests for each API
funcs = {n: f for n, f in globals().items() if n.startswith('_test')}
for api, cmd in APIS.items():
    for f in funcs.values():
        create_test(api, cmd, f)
