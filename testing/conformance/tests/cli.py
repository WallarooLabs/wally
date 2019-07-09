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


# This first import is required for integration harness and wallaroo lib
# imports to work (it does path mungling to ensure they're available)
import conformance

import json
from integration import clear_current_test
from integration.external import run_shell_cmd

# Test specific imports
from conformance.applications.cli import (CLITesterPython2,
                                          CLITesterPython3)


class Query(object):
    def __init__(self, cluster, query_type):
        self.cmd = "external_sender --json --external {} --type {}"
        self.cmds = {w.name: self.cmd.format(w.external, query_type) for w
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
                            format(self.cmd, res.output))



INPUT_SIZE = 10

@clear_current_test
def test_cli_python2_partition_query():
    with CLITesterPython2({'workers': 3}) as test:
        test.send_data()
        q = Query(test.cluster, "partition-query")
        got = q.result()['initializer']

        assert(sorted(["state_partitions","stateless_partitions"]) ==
               sorted(got.keys()))
        for k in got["state_partitions"].keys():
          assert("initializer" in got["state_partitions"][k])


@clear_current_test
def test_cli_python3_partition_query():
    with CLITesterPython3({'workers': 3}) as test:
        test.send_data()
        q = Query(test.cluster, "partition-query")
        got = q.result()['initializer']

        assert(sorted(["state_partitions","stateless_partitions"]) ==
               sorted(got.keys()))
        for k in got["state_partitions"].keys():
          assert("initializer" in got["state_partitions"][k])


@clear_current_test
def test_cli_python2_partition_count_query():
    with CLITesterPython2() as test:
        test.send_data()
        got = Query(test.cluster, "partition-count-query").result()['initializer']

        assert(sorted(got.keys()) ==
               ["state_partitions", "stateless_partitions"])
        assert(len(got['stateless_partitions']) == 1)
        assert(len(got['state_partitions']) == 2)
        for v in got['state_partitions'].values():
            assert(v['initializer'] == test.input_size)


@clear_current_test
def test_cli_python3_partition_count_query():
    with CLITesterPython3() as test:
        test.send_data()
        got = Query(test.cluster, "partition-count-query").result()['initializer']

        assert(sorted(got.keys()) ==
               ["state_partitions", "stateless_partitions"])
        assert(len(got['stateless_partitions']) == 1)
        assert(len(got['state_partitions']) == 2)
        for v in got['state_partitions'].values():
            assert(v['initializer'] == test.input_size)


@clear_current_test
def test_cli_python2_cluster_status_query():
    with CLITesterPython2({'workers': 2}) as test:
        q = Query(test.cluster, "cluster-status-query")
        got = q.result()

        for w in got.values():
            assert(w ==
                   {u"processing_messages": True,
                    u"worker_names": [u"initializer", u"worker1"],
                    u"worker_count": 2})


@clear_current_test
def test_cli_python3_cluster_status_query():
    with CLITesterPython3({'workers': 2}) as test:
        q = Query(test.cluster, "cluster-status-query")
        got = q.result()

        for w in got.values():
            assert(w ==
                   {u"processing_messages": True,
                    u"worker_names": [u"initializer", u"worker1"],
                    u"worker_count": 2})

@clear_current_test
def test_cli_python2_source_ids_query():
    defined_source_parallelism = 13 # see dummy.py TCPSourceconfig
    with CLITesterPython2() as test:
        test.send_data()
        q = Query(test.cluster, "source-ids-query")
        got = q.result()['initializer']

        assert(list(got.keys()) == ["source_ids"])
        assert(len(got["source_ids"]) == defined_source_parallelism)


@clear_current_test
def test_cli_python3_source_ids_query():
    defined_source_parallelism = 13 # see dummy.py TCPSourceconfig
    with CLITesterPython3() as test:
        test.send_data()
        q = Query(test.cluster, "source-ids-query")
        got = q.result()['initializer']

        assert(list(got.keys()) == ["source_ids"])
        assert(len(got["source_ids"]) == defined_source_parallelism)


@clear_current_test
def test_cli_python2_state_entity_query():
    with CLITesterPython2({'workers': 2}) as test:
        test.send_data()
        q = Query(test.cluster, "state-entity-query")
        got = q.result()

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
        assert(len(part_ids) == test.input_size)
        assert(single_part_id.split("-")[0] == 'collect')
        # check that there are two computation ids
        comp_ids = set()
        for w in got.values():
            for key in w:
                comp_ids.add(key)
        assert(len(comp_ids) == 2)


@clear_current_test
def test_cli_python3_state_entity_query():
    with CLITesterPython3({'workers': 2}) as test:
        test.send_data()
        q = Query(test.cluster, "state-entity-query")
        got = q.result()

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
        assert(len(part_ids) == test.input_size)
        assert(single_part_id.split("-")[0] == 'collect')
        # check that there are two computation ids
        comp_ids = set()
        for w in got.values():
            for key in w:
                comp_ids.add(key)
        assert(len(comp_ids) == 2)


@clear_current_test
def test_cli_python2_state_entity_count_query():
    with CLITesterPython2({'workers': 2}) as test:
        test.send_data()
        q = Query(test.cluster, "state-entity-count-query")
        got = q.result()

        comps = {}
        for w in got.values():
            for k, v in w.items():
                comps[k] = comps.get(k, 0) + v
        assert(set(comps.values()) == set((1,10)))


@clear_current_test
def test_cli_python3_state_entity_count_query():
    with CLITesterPython3({'workers': 2}) as test:
        test.send_data()
        q = Query(test.cluster, "state-entity-count-query")
        got = q.result()

        comps = {}
        for w in got.values():
            for k, v in w.items():
                comps[k] = comps.get(k, 0) + v
        assert(set(comps.values()) == set((1,10)))


@clear_current_test
def test_cli_python2_stateless_partition_query():
    with CLITesterPython2({'workers': 2}) as test:
        got = Query(test.cluster, "stateless-partition-query").result()

        for w, res in got.items():
            for k, v in res.items():
                assert(int(k))
                assert(w in v.keys())
                assert(len(v[w]) == test.input_size)


@clear_current_test
def test_cli_python3_stateless_partition_query():
    with CLITesterPython3({'workers': 2}) as test:
        got = Query(test.cluster, "stateless-partition-query").result()

        for w, res in got.items():
            for k, v in res.items():
                assert(int(k))
                assert(w in v.keys())
                assert(len(v[w]) == test.input_size)


@clear_current_test
def test_cli_python2_stateless_partition_count_query():
    with CLITesterPython2({'workers': 2}) as test:
        got = Query(test.cluster, "stateless-partition-count-query").result()

        for w, res in got.items():
            for k, v in res.items():
                assert(int(k))
                assert(v == {w : test.input_size})


@clear_current_test
def test_cli_python3_stateless_partition_count_query():
    with CLITesterPython3({'workers': 2}) as test:
        got = Query(test.cluster, "stateless-partition-count-query").result()

        for w, res in got.items():
            for k, v in res.items():
                assert(int(k))
                assert(v == {w : test.input_size})
