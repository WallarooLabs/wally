# Copyright 2017 The Wallaroo Authors.
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

from itertools import chain

from errors import NotEmptyError


def validate_migration(pre_partitions, post_partitions, workers):
    """
    - Test that no "joining" workers are present in the pre set
    - Test that no "leaving" workers are present in the post set
    - Test that state partitions moved between the pre_partitions map and
      the post_partitions map.
    - Test that all of the states present in the `pre` set are also present
      in the `post` set. New state are allowed in the `post` because of
      dynamic partitioning (new partitions may be created in real time).
    """
    # prepare some useful sets for set-wise comparison
    pre_parts = {step: set(pre_partitions[step].keys()) for step in
                 pre_partitions}
    post_parts = {step: set(post_partitions[step].keys()) for step in
                  post_partitions}
    pre_workers = set(chain(*[pre_partitions[step].values() for step in
                             pre_partitions]))
    post_workers = set(chain(*[post_partitions[step].values() for step in
                               post_partitions]))
    joining = set(workers.get('joining', []))
    leaving = set(workers.get('leaving', []))

    # test no joining workers are present in pre set
    assert((pre_workers - joining) == pre_workers)

    # test no leaving workers are present in post set
    assert((post_workers - leaving) == post_workers)

    # test that no parts go missing after migration
    for step in pre_parts:
        assert(step in post_parts)
        assert(post_parts[step] <= pre_parts[step])

    # test that state parts moved between pre and post (by step)
    for step in pre_partitions:
        # Test step did not disappear after migration
        assert(step in post_partitions)
        # Test some partitions moved
        assert(pre_partitions[step] != post_partitions[step])


def is_processing(status):
    """
    Test that the cluster's 'processing_messages' status is True
    """
    assert(status['processing_messages'] is True)


def worker_count_matches(status, count):
    """
    Test that `count` workers are reported as active in the
    cluster status query response
    """
    assert(len(status['worker_names']) == count)
    assert(status['worker_count'] == count)


def worker_has_state_entities(state_entities):
    """
    Test that the worker has state_entities
    """
    assert(len(state_entities) > 0)  # There's at least one state partition
    for state_name in state_entities:  # iterate over each partition
        assert(len(state_entities[state_name]) > 0)  # At least one entity


def validate_sender_is_flushed(sender):
    """
    Test that a sender has flushed its buffer
    """
    if sender.batch:
        raise NotEmptyError
