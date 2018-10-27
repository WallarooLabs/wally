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

import logging
import threading

class StoppableThread(threading.Thread):
    """
    A convenience baseclass for daemonized, stoppable thread classes.
    """
    def __init__(self):
        super(StoppableThread, self).__init__()
        self.daemon = True
        self.stop_event = threading.Event()
        self.error = None

    def stop(self, error=None):
        self.stop_event.set()
        if error:
            logging.debug("{} stopped with error".format(self.name))
            logging.debug(error)
            self.error = error

    def stopped(self):
        return self.stop_event.is_set()
