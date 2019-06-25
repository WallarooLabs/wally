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


"""
Clear out previous test run temp data
"""

import os
import shutil

from .external import makedirs_if_not_exists
from .logger import add_file_logger


BASE_LOG_DIR = '/tmp/wallaroo_test_errors/current_test'
print("Clearing out {}".format(BASE_LOG_DIR))
shutil.rmtree(BASE_LOG_DIR, True)

# Create the dir again
makedirs_if_not_exists(BASE_LOG_DIR)

# Add a file logger saving to it in DEBUG level
log_file = 'test.log'
log_path = os.path.join(BASE_LOG_DIR, log_file)
add_file_logger(log_path)


def _clean_base_log_dir():
        # clean the current test log dir
        for f in os.listdir(BASE_LOG_DIR):
            if f == 'test.log':
                with open(os.path.join(BASE_LOG_DIR, f), 'wb'):
                    pass
                continue
            file_path = os.path.join(BASE_LOG_DIR, f)
            if os.path.isfile(file_path):
                os.remove(file_path)
            elif os.path.isdir(file_path):
                shutil.rmtree(file_path)


def clear_current_test(func):
    def wrapper(*args, **kwargs):
        # clean base log dir
        _clean_base_log_dir()
        # execute the wrapped function
        with open(os.path.join(BASE_LOG_DIR, func.__name__), 'wt'):
            pass
        res = func(*args, **kwargs)
        # clean base log dir again...
        _clean_base_log_dir()
        # return wrapped function's output
        return res
    return wrapper
