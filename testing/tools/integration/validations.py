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
import logging

from .errors import (MigrationError,
                    NotEmptyError)


def validate_migration(pre_partitions, post_partitions, workers):
    """
    - Test that no "joining" workers are present in the pre set
    - Test that no "leaving" workers are present in the post set
    - Test that state partitions moved between the pre_partitions map and
      the post_partitions map if they needed to
    - Test that all of the states present in the `pre` set are also present
      in the `post` set. New states are allowed in the `post` because of
      dynamic partitioning (new partitions may be created in real time).
    """
    # prepare some useful sets for set-wise comparison
    pre_parts = {state: set(pre_partitions[state].keys()) for state in
                 pre_partitions}
    post_parts = {state: set(post_partitions[state].keys()) for state in
                  post_partitions}
    pre_workers = set(chain(*[pre_partitions[state].values() for state in
                             pre_partitions]))
    post_workers = set(chain(*[post_partitions[state].values() for state in
                               post_partitions]))
    joining = set(workers.get('joining', []))
    leaving = set(workers.get('leaving', []))

    # test no joining workers are present in pre set
    logging.debug("Test no joining workers are present in pre set")
    try:
        assert((pre_workers - joining) == pre_workers)
    except:
        raise MigrationError("Joining-workers-in-pre-set error.")

    # test no leaving workers are present in post set
    logging.debug("test no leaving workers are present in post set")
    try:
        assert((post_workers - leaving) == post_workers)
    except:
        raise MigrationError("Leaving-workers-in-the-post-set error.")

    # test that no keys go missing after migration
    logging.debug("test that no keys go missing after migration")
    for state in pre_parts:
        # each state from before is still around:
        try:
            assert(state in post_parts)
        except:
            raise MigrationError("State {!r} is missing from post set"
                .format(state))
        # for each state, each key before migration existed after
        try:
            assert(pre_parts[state] <= post_parts[state]) # set.issubset
        except:
            raise MigrationError("Keys from before migration are missing: {!r}"
                    .format(pre_parts[state] - post_parts[state]))

    # test that keys moved between pre and post (by state)
    logging.debug("test that keys moved between pre and post (by state)")
    for state in pre_partitions:
        # Test step did not disappear after migration
        try:
            assert(state in post_partitions)
        except:
            raise MigrationError("State {!r} is missing from post_partitions"
                .format(state))
        # Test some partitions moved
        for key, worker in pre_partitions[state].items():
            try:
                if worker in leaving:
                    assert(pre_partitions[state] != post_partitions[state])
                else:
                    continue
            except:
                raise MigrationError("Partition {!r} for state {!r} did not "
                    "move from worker {!r}"
                    .format(key, state, worker))


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
