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


import collections
import datetime
import logging
import os
import sys
import time

from integration.cluster import (Cluster,
                                 runner_data_format)

from integration.logger import (add_in_memory_log_stream,
                                set_logging)

from integration.end_points import (iter_generator,
                                    Reader,
                                    Sender)

from integration.external import save_logs_to_file

from .control import CompletesWhenNotifier


FROM_TAIL = int(os.environ.get("FROM_TAIL", 10))
logging.root.name = "conformance"


def update_dict(d, u):
    for k, v in u.items():
        if isinstance(v, collections.abc.Mapping):
            d[k] = update_dict(d.get(k, {}), v)
        else:
            d[k] = v
    return d


class TestHarnessException(Exception):
    pass


class Application:
    name = 'BaseApplication'
    command = None
    config = {}
    host = '127.0.0.1'
    workers = 1
    sources = ['Detector']
    sinks = 1
    sink_mode = 'framed'
    split_streams = True
    log_rotation = False
    sender_join_timeout = 120

    ##########
    # In/Out #
    ##########
    def send(self, data, src_name=None, block=True, sender_cls=Sender):
        logging.debug("send(data={!r}, src_name={!r}, block={!r}, sender_cls="
                "{!r}".format(data, src_name, block, sender_cls))
        if not self.cluster:
            raise TestHarnessException("Can't add a sender before creating "
                    "a cluster!")
        if src_name is None:
            src_name = self.sources[0]
        gen = iter_generator(items = data,
                             to_bytes = self.serialise_input)
        sender = sender_cls(address = self.cluster.source_addrs[0][src_name],
                        reader = Reader(gen))
        self.cluster.add_sender(sender, start=True)
        if block:
            sender.join(self.sender_join_timeout)
            if sender.error:
                raise sender.error
        logging.debug("end of send_tcp")
        return sender

    def completes_when(self, test_func, timeout=90):
        notifier = CompletesWhenNotifier(self, test_func,
            timeout, period=0.1)
        notifier.start()
        notifier.join()
        if notifier.error:
            raise notifier.error

    ####################
    # User Overridable #
    ####################
    def serialise_input(self, v):
        return v.encode()

    def parse_output(self, v):
        return v.decode()

    def sink_await(self, values, timeout=90, func=lambda x: x, sink=-1):
        if not self.cluster:
            raise TestHarnessException("Can't sink_await before creating "
                    "a cluster!")
        self.cluster.sink_await(values, timeout, func, sink)

    def sink_expect(self, expected, timeout=90, sink=-1, allow_more=False):
        if not self.cluster:
            raise TestHarnessException("Can't sink_expect before creating "
                    "a cluster!")
        self.cluster.sink_expect(expected=expected,
                                 timeout=timeout,
                                 sink=sink,
                                 allow_more=allow_more)

    def collect(self, sink=None):
        if not self.cluster:
            raise TestHarnessException("Can't collect before creating "
                    "a cluster!")
        if sink:
            return self.cluster.sinks[sink].data
        return self.cluster.sinks[0].data

    #####################
    ## Context Manager ##
    #####################
    def __init__(self):
        self.log_stream = add_in_memory_log_stream(level=logging.DEBUG)
        current_test = (os.environ.get('PYTEST_CURRENT_TEST')
                        .rsplit(' (call)')[0])
        cwd = os.getcwd()
        trunc_head = cwd.find('/wallaroo/') + len('/wallaroo/')
        t0 = datetime.datetime.now()
        self.base_dir = os.path.join('/tmp/wallaroo_test_errors',
            cwd[trunc_head:],
            current_test,
            t0.strftime('%Y%m%d_%H%M%S'))
        self.persistent_data = {}

    def __enter__(self):
        try:
            if self.command is None:
                raise ValueError("command cannot be None. Please initialize {}"
                        " with a valid command argument!".format(
                            self))
            command = "{} {}".format(self.command,
                " ".join(("--{} {}".format(k, v)
                          for k, v in self.config.get('command_parameters', {})
                                                 .items())))
            if os.environ.get("resilience") == 'on':
                    command += ' --run-with-resilience'
            self.cluster = Cluster(command = command,
                         host = self.host,
                         sources = self.sources,
                         workers = self.workers,
                         split_streams = self.split_streams,
                         log_rotation = self.log_rotation,
                         persistent_data = self.persistent_data)
            self.cluster.__enter__()
            time.sleep(0.1)
            return self
        except:
            logging.warning("Encountered an exception when entering the"
                            " context")
            exc_type, exc_value, exc_traceback = sys.exc_info()
            self.__exit__(exc_type, exc_value, exc_traceback)

    def __exit__(self, _type, _value, _traceback):
        logging.debug("{}.__exit__({}, {}, {})".format(self, _type, _value,
            _traceback))
        try:
            self.cluster.__exit__(None, None, None)
        except Exception as err:
            #logging.exception(err)
            pass
        if _type or _value or _traceback:
            crashed_workers = list(
                filter(lambda r: r.returncode not in (0,-9,-15),
                       self.persistent_data.get('runner_data', [])))
            if crashed_workers:
                logging.error("Some workers exited badly. The last {} lines of "
                    "each were:\n\n{}"
                    .format(FROM_TAIL,
                        runner_data_format(
                            self.persistent_data.get('runner_data', []),
                            from_tail=FROM_TAIL)))

            save_logs_to_file(self.base_dir,
                              self.log_stream,
                              self.persistent_data)
        if _value is not None:
            raise _value
