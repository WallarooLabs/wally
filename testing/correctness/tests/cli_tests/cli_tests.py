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

INPUT_ITEMS=10
CMD='machida --application-module dummy'

# If resilience is on, add --run-with-resilience to commands
if os.environ.get("resilience") == 'on':
    CMD += ' --run-with-resilience'


def test_partition_query():
    with LoggingTestContext() as ctx:
        with ctx.Cluster(command=CMD, workers=3) as cluster:
            q = Query(cluster, "partition-query")
            got = q.result()

        assert(sorted(["state_partitions","stateless_partitions"]) ==
               sorted(got.keys()))
        print(got)
        for k in got["state_partitions"].keys():
          assert("initializer" in got["state_partitions"][k])


def test_partition_count_query():
    with LoggingTestContext() as ctx:
        with ctx.Cluster(command=CMD) as cluster:
            given_data_sent(cluster)
            got = Query(cluster, "partition-count-query").result()

        assert(sorted(got.keys()) ==
               ["state_partitions", "stateless_partitions"])
        assert(got["state_partitions"] ==
               {u"DummyState": {u"initializer": 1},
                u"PartitionedDummyState": {u"initializer": INPUT_ITEMS}})
        for (k, v) in got["stateless_partitions"].items():
            assert(int(k))
            assert(v == {u"initializer": 1})


def test_cluster_status_query():
    with LoggingTestContext() as ctx:
        with ctx.Cluster(command=CMD, workers=2) as cluster:
            q = Query(cluster, "cluster-status-query")
            got = q.result()

        assert(got ==
               {u"processing_messages": True,
                u"worker_names": [u"initializer", u"worker1"],
                u"worker_count": 2})


def test_source_ids_query():
    HARDCODED_NO_OF_SOURCE_IDS = 10
    with LoggingTestContext() as ctx:
        with ctx.Cluster(command=CMD, sources=1) as cluster:
            given_data_sent(cluster)
            q = Query(cluster, "source-ids-query")
            got = q.result()

        assert(list(got.keys()) == ["source_ids"])
        assert(len(got["source_ids"]) == HARDCODED_NO_OF_SOURCE_IDS)


def test_state_entity_query():
    with LoggingTestContext() as ctx:
        with ctx.Cluster(command=CMD, workers=2) as cluster:
            given_data_sent(cluster)
            got = Query(cluster, "state-entity-query").result()

        assert(sorted(got.keys()) == [u'DummyState', u'PartitionedDummyState'])
        assert(got[u'DummyState'] == [u'key'])
        assert(len(got[u'PartitionedDummyState']) == 7)


def test_state_entity_count_query():
    with LoggingTestContext() as ctx:
        with ctx.Cluster(command=CMD, workers=2) as cluster:
            given_data_sent(cluster)
            q = Query(cluster, "state-entity-count-query")
            got = q.result()

        assert(got == {u'DummyState':1,
                              u'PartitionedDummyState':7})


def test_stateless_partition_query():
    with LoggingTestContext() as ctx:
        with ctx.Cluster(command=CMD, workers=2) as cluster:
            got = Query(cluster, "stateless-partition-query").result()

        for (k,v) in got.items():
            assert(int(k))
            assert(sorted(v.keys()) == [u"initializer", u"worker1"])
            assert(len(v[u"initializer"]) == 1)
            assert(int((v[u"initializer"])[0]))
            assert(len(v[u"worker1"]) == 1)
            assert(int((v[u"worker1"])[0]))


def test_stateless_partition_count_query():
    with LoggingTestContext() as ctx:
        with ctx.Cluster(command=CMD, workers=2) as cluster:
            got = Query(cluster, "stateless-partition-count-query").result()

        for (k,v) in got.items():
            assert(int(k))
            assert(v == {u"initializer" : 1, u"worker1": 1})


def given_data_sent(cluster):
    reader = Reader(iter_generator([chr(x+65) for x in range(INPUT_ITEMS)]))
    sender = Sender(cluster.source_addrs[0],
                    reader,
                    batch_size=50, interval=0.05, reconnect=True)
    cluster.add_sender(sender, start=True)
    time.sleep(0.5)


class Query(object):
    def __init__(self, cluster, type):
        cmd = "external_sender --json --external {} --type {}"
        self._cmd = cmd.format(cluster.workers[0].external, type)

    def result(self):
        res = run_shell_cmd(self._cmd)
        if res.success:
            try:
                return json.loads(res.output)
            except:
                raise Exception("Failed running parser on {!r}".
                                format(res.output))
        else:
            raise Exception("Failed running cmd: {!r} with {!r}".
                            format(self._cmd, res.output))
