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


# Add integration and  wallaroo libs to import path
import sys
import os
cwd = os.getcwd()
root = cwd.rsplit("/testing/conformance")[0]
testing_tools  = os.path.join(root, "testing", "tools")
wallaroo_lib = os.path.join(root, "machida", "lib")
sys.path.append(testing_tools)
sys.path.append(wallaroo_lib)
