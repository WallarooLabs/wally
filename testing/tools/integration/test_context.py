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

import datetime
import logging
import os
import sys

from .cluster import (Cluster,
                      runner_data_format)

from .errors import (RunnerHasntStartedError,
                     SinkAwaitTimeoutError,
                     TimeoutError)

from .external import save_logs_to_file

from .logger import add_in_memory_log_stream


FROM_TAIL = int(os.environ.get("FROM_TAIL", 10))


def get_caller_name(go_back=1):
    """
    Convenience method for passing the scope's name to the LoggingContext
    so it can create a useful path for saving the capture logs and test data
    """
    fr = sys._getframe()
    for x in range(go_back):
        fr_ = fr.f_back
        if fr_ is not None:
            fr = fr_
        else:
            break
    return fr.f_code.co_name


class LoggingTestContext(object):
    """
    A context manager class for handling logging in case of test failures
    """
    def __init__(self, api=None, name_arg=None):
        self.t0 = datetime.datetime.now()
        self.log_stream = add_in_memory_log_stream(level=logging.DEBUG)
        self.persistent_data = {}
        self.api = api
        if name_arg is None:
            name_arg = get_caller_name(2)
        self.name_arg = name_arg

    def __enter__(self):
        return self

    def cluster(self, *args, **kwargs):
        pd = kwargs.pop('persistent_data', None)
        kwargs['persistent_data'] = self.persistent_data
        return Cluster(*args, **kwargs)

    def Cluster(self, *args, **kwargs):
        return self.cluster(*args, **kwargs)

    def __exit__(self, _type, _value, _traceback):
        logging.log(1, "__exit__({}, {}, {})"
            .format(_type, _value, _traceback))
        # clean up any remaining runner processes
        if _type or _value or _traceback:
            # Error handling logic
            ######################
            # Note that while normally we would use something like
            # `isinstance(err, ErrorType)`, here _type is a class and not an
            # instance, so we use equality with error classes instead.

            # Data artifact handling logic
            ##############################

            if self.persistent_data.get('runner_data'):
                output = runner_data_format(
                    self.persistent_data.get('runner_data'),
                    from_tail=FROM_TAIL)
                if output:
                    logging.error("Some workers exited badly. The last {} "
                        "lines of each were:\n\n{}".format(FROM_TAIL, output))

            # Save log stream and cluster data to file
            ##########################################
            try:
                cwd = os.getcwd()
                trunc_head = cwd.find('/wallaroo/') + len('/wallaroo/')
                base_dir = ('/tmp/wallaroo_test_errors/{head}/{api}{name_arg}'
                    '{time}'.format(
                        head=cwd[trunc_head:],
                        api="{}/".format(self.api) if self.api else "",
                        name_arg=("{}/".format(self.name_arg)
                            if self.name_arg else ""),
                        time=self.t0.strftime('%Y%m%d_%H%M%S')))
                save_logs_to_file(base_dir, self.log_stream,
                    self.persistent_data)
            except Exception as err_inner:
                logging.exception(err_inner)
                logging.warning("Encountered an error when saving logs files "
                    "to {}".format(base_dir))

            logging.error('An error was raised in the Logging Test Context',
                exc_info=(_type, _value, _traceback))
