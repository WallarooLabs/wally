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


class TypedList(list):
    def __init__(self, iterable=None, types=None):
        super(TypedList, self).__init__()
        self.types = types
        if iterable:
            for item in iterable:
                self.append(item)

    def type_check(self, item):
        if self.types and not isinstance(item, self.types):
            raise TypeError('TypedList[{}] does not accept {} of type {}'
                .format(self.types, item, type(item)))

    def append(self, item):
        self.type_check(item)
        super(TypedList, self).append(item)

    def insert(self, index, item):
        self.type_check(item)
        super(TypedList, self).insert(index, item)

    def __add__(self, item):
        self.type_check(item)
        super(TypedList, self).__add__(item)

    def __iadd__(self, item):
        self.type_check(item)
        super(GhostList, self).__iadd__(item)
